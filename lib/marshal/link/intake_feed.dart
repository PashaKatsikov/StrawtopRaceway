import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../flag_book.dart';
import '../trace.dart';
import 'wire_client.dart';

/// Install intake: warm-up, install / re-open / deep-link capture, the
/// second look at an "Organic" verdict, and the flat body the beacon expects.
class IntakeFeed {
  IntakeFeed(this._wire);

  final WireClient _wire;

  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;
  Future<void>? _liftFuture;

  final Completer<void> _installSeen = Completer<void>();
  final Completer<void> _deepLinkSeen = Completer<void>();

  Future<void> lift() => _liftFuture ??= _lift();

  Future<void> _lift() async {
    if (!FlagBook.ready) {
      _releaseWaiters();
      return;
    }
    try {
      await _askTracking();
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: FlagBook.intakeKey,
          appId: FlagBook.storeNumber,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 6,
        ),
      );
      _sdk = sdk;
      sdk.onInstallConversionData(_absorbInstall);
      sdk.onAppOpenAttribution((raw) => _reopen = _flatten(raw));
      sdk.onDeepLinking((result) {
        final click = result.deepLink?.clickEvent;
        if (click != null) _deepLink = Map<String, dynamic>.from(click);
        if (!_deepLinkSeen.isCompleted) _deepLinkSeen.complete();
      });
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      gridNote(() => 'mrs:intake lift failed: $error');
      _releaseWaiters();
    }
  }

  /// The prompt must land after the first frame, otherwise iOS drops it.
  Future<void> _askTracking() async {
    if (!Platform.isIOS) return;
    final state = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (state != TrackingStatus.notDetermined) return;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(FlagBook.trackingPromptDelay);
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  Future<void> _absorbInstall(dynamic raw) async {
    try {
      final data = _flatten(raw);
      final status = data['status']?.toString().toLowerCase();
      // The SDK reports {status: failure, ...} when it cannot reach its own
      // servers (an ad-blocking VPN, for example). That error map must never
      // be merged into the body.
      final broken = status == 'failure' ||
          (data['af_status'] == null && data.containsKey('status'));
      gridNote(
        () => 'mrs:intake status=$status af_status=${data['af_status']} '
            'keys=${data.keys.toList()}',
      );
      if (broken) {
        _install = const <String, dynamic>{};
      } else if (data['af_status'] == 'Organic') {
        _install = await _secondLook(data);
      } else {
        _install = data;
      }
    } catch (error) {
      gridNote(() => 'mrs:intake read failed: $error');
      _install = const <String, dynamic>{};
    } finally {
      if (!_installSeen.isCompleted) _installSeen.complete();
    }
  }

  /// An early "Organic" is often a false positive — the attribution record can
  /// still be in flight. Wait, then ask the install-data lookup directly.
  Future<Map<String, dynamic>> _secondLook(Map<String, dynamic> data) async {
    await Future<void>.delayed(
      const Duration(seconds: FlagBook.organicReviewSeconds),
    );
    return await _lookupInstall() ?? data;
  }

  Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final inner = map['payload'];
    return inner is Map ? Map<String, dynamic>.from(inner) : map;
  }

  Future<Map<String, dynamic>?> _lookupInstall() async {
    final device = await intakeId();
    if (device == null || device.isEmpty) return null;
    try {
      // The lookup keys off the numeric store id on iOS, not the bundle id.
      final base = FlagBook.intakeLookupUrl;
      final joiner = base.contains('?') ? '&' : '?';
      final uri = Uri.parse(
        '$base${joiner}app_id=${FlagBook.storeNumber}&device_id=$device',
      );
      final response = await _wire
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer ${FlagBook.intakeKey}',
            },
          )
          .timeout(FlagBook.intakeLookupTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> settle({Duration installWait = FlagBook.installWait}) async {
    await lift();
    await Future.wait<void>(<Future<void>>[
      _installSeen.future.timeout(installWait, onTimeout: () {}),
      _deepLinkSeen.future.timeout(FlagBook.deepLinkWait, onTimeout: () {}),
    ]);
  }

  Future<String?> intakeId() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Field names below are the beacon contract — never rename or drop one.
  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    if (_install != null) body.addAll(_install!);
    for (final extra in <Map<String, dynamic>?>[_reopen, _deepLink]) {
      extra?.forEach((key, value) => body.putIfAbsent(key, () => value));
    }

    body['af_id'] = await intakeId() ?? body['af_id'] ?? '';
    body['bundle_id'] = FlagBook.bundleId;
    body['os'] = 'iOS';
    body['store_id'] = FlagBook.storeToken;
    body['locale'] = locale;
    if (pushToken != null &&
        pushToken.isNotEmpty &&
        FlagBook.signalProject.isNotEmpty) {
      body['push_token'] = pushToken;
      body['firebase_project_id'] = FlagBook.signalProject;
    }
    final adId = await _advertisingId();
    if (adId != null) body['sub_id_10'] = adId;

    gridNote(() => 'mrs:intake body ${jsonEncode(body)}');
    return body;
  }

  Future<String?> _advertisingId() async {
    if (!Platform.isIOS) return null;
    try {
      final state = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (state != TrackingStatus.authorized) return null;
      final id = await AppTrackingTransparency.getAdvertisingIdentifier();
      if (id.isEmpty || id.startsWith('00000000-')) return null;
      return id;
    } catch (_) {
      return null;
    }
  }

  void _releaseWaiters() {
    if (!_installSeen.isCompleted) _installSeen.complete();
    if (!_deepLinkSeen.isCompleted) _deepLinkSeen.complete();
  }
}
