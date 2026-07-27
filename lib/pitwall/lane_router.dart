import 'dart:async';
import 'dart:io';

import 'config/track_config.dart';
import 'core/lane_models.dart';
import 'infra/cold_tap_reader.dart';
import 'infra/config_relay.dart';
import 'infra/pit_vault.dart';
import 'infra/pit_agent.dart';
import 'infra/pulse_hub.dart';
import 'infra/reach_probe.dart';
import 'infra/track_attribution.dart';

/// The whole pit-flow routing brain. [resolve] runs the cold-start → network →
/// attribution → config pipeline once and returns where to send the user.
class LaneRouter {
  LaneRouter({
    required this.vault,
    required this.probe,
    required this.attribution,
    required this.relay,
    required this.pulse,
    required this.agent,
    required this.runtimeEnabled,
  });

  final PitVault vault;
  final ReachProbe probe;
  final TrackAttribution attribution;
  final ConfigRelay relay;
  final PulseHub pulse;
  final PitAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && TrackConfig.grayCredentialsReady;

  Future<LaneStop>? _pending;

  /// De-duplicates only *concurrent* calls (the splash can build twice at
  /// startup). The cache clears on completion so a later Retry re-runs the
  /// whole pipeline instead of replaying a cached OfflineStop forever.
  Future<LaneStop> resolve({
    required void Function(double value) onProgress,
  }) =>
      _pending ??=
          _resolve(onProgress: onProgress).whenComplete(() => _pending = null);

  Future<LaneStop> _resolve({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      assert(() {
        // ignore: avoid_print
        print(
          '[STW.LANE] gate disabled runtime=$runtimeEnabled '
          'creds=${TrackConfig.grayCredentialsReady}',
        );
        return true;
      }());
      onProgress(1);
      return const NativeStop();
    }

    assert(() {
      // ignore: avoid_print
      print('[STW.LANE] resolve start route=${vault.route}');
      return true;
    }());

    pulse.onTokenChanged = _refreshForToken;
    final coldUrl = await ColdTapReader.consume();
    if (coldUrl != null) {
      await vault.saveRoute(LaneRoute.portal);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return PortalStop(coldUrl, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (vault.route) {
      LaneRoute.undecided => _firstDecision(onProgress),
      LaneRoute.portal => _returningPortal(onProgress),
      LaneRoute.native => _returningNative(onProgress),
    };
  }

  Future<LaneStop> _firstDecision(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(0.28);
    try {
      await pulse.boot();
    } catch (_) {}
    if (!await probe.canReachNetwork()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(0.48);
    await attribution.awaitSignals();
    progress(0.72);
    final reply = await _requestConfig();
    progress(1);
    assert(() {
      // ignore: avoid_print
      print('[STW.LANE] first: hasDest=${reply.hasDestination} url=${reply.url}');
      return true;
    }());
    if (reply.hasDestination) {
      await vault.saveRoute(LaneRoute.portal);
      return PortalStop(reply.url!);
    }
    await vault.saveRoute(LaneRoute.native);
    return const NativeStop();
  }

  Future<LaneStop> _returningPortal(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      return const OfflineStop(returnToNative: false);
    }
    final pending = await vault.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return PortalStop(pending);
    }
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return PortalStop(cached);
    }

    await Future.wait<void>(<Future<void>>[
      pulse.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(0.62);
    await attribution.awaitSignals(installTimeout: const Duration(seconds: 5));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return PortalStop(reply.url!);
    if (cached != null) return PortalStop(cached);
    return const OfflineStop(returnToNative: false);
  }

  Future<LaneStop> _returningNative(void Function(double) progress) async {
    if (!await probe.hasInterface()) {
      progress(1);
      return const NativeStop();
    }
    await Future.wait<void>(<Future<void>>[
      pulse.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      progress(1);
      return const NativeStop();
    }
    progress(0.55);
    await attribution.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const NativeStop();
    await vault.saveRoute(LaneRoute.portal);
    return PortalStop(reply.url!);
  }

  Future<GateReply> _requestConfig({String? token}) async {
    final body = await attribution.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? pulse.token,
    );
    return relay.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        pulse.boot(),
        attribution.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
