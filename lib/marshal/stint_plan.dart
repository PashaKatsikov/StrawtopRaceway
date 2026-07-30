import 'dart:async';
import 'dart:io';

import 'flag_book.dart';
import 'link/beacon_call.dart';
import 'link/boot_link.dart';
import 'link/intake_feed.dart';
import 'link/locker.dart';
import 'link/net_watch.dart';
import 'link/ping_desk.dart';
import 'link/wire_client.dart';
import 'stint_types.dart';
import 'trace.dart';

/// The routing brain. [decide] walks the cold-tap → link → intake → beacon
/// pipeline once per launch and reports where this launch belongs.
class StintPlan {
  StintPlan({
    required this.locker,
    required this.watch,
    required this.intake,
    required this.beacon,
    required this.ping,
    required this.wire,
    required this.armed,
  });

  final Locker locker;
  final NetWatch watch;
  final IntakeFeed intake;
  final BeaconCall beacon;
  final PingDesk ping;
  final WireClient wire;
  final bool armed;

  bool get active => armed && FlagBook.ready;

  Future<StintExit>? _inFlight;

  /// Collapses *concurrent* calls only — the splash can build twice during
  /// startup. The handle is released on completion so a later retry walks the
  /// whole pipeline again instead of replaying a stale verdict forever.
  Future<StintExit> decide() =>
      _inFlight ??= _walk().whenComplete(() => _inFlight = null);

  Future<StintExit> _walk() async {
    if (!active) {
      gridNote(() => 'mrs:plan inert armed=$armed ready=${FlagBook.ready}');
      return const GarageExit();
    }
    gridNote(() => 'mrs:plan walk lane=${locker.lane}');

    ping.onToken = _repostWithToken;

    // A cold tap outranks everything else: reading it late loses the
    // destination to a timeout race and lands the user on the menu instead.
    final cold = await BootLink.take();
    if (cold != null) return _afterCold(cold);

    return switch (locker.lane) {
      StintLane.board => _boardAgain(),
      StintLane.garage => _garageAgain(),
      StintLane.unset => _openingLap(),
    };
  }

  Future<StintExit> _afterCold(String url) async {
    await locker.writeLane(StintLane.board);
    await locker.takeQueued();
    unawaited(_catchUp());
    return BoardExit(url, fromCold: true);
  }

  /// First launch on this device. Only a successful beacon reply *without* a
  /// target may commit the garage lane — committing it on a transport failure
  /// would trap an attributed install in the game forever.
  Future<StintExit> _openingLap() async {
    if (!await watch.hasLink()) return const DarkExit();
    try {
      await ping.wake();
    } catch (_) {}
    if (!await watch.canReachOut()) return const DarkExit();

    await intake.settle();
    final reply = await _post();
    gridNote(
      () => 'mrs:plan opening target=${reply.hasTarget} url=${reply.url}',
    );
    if (reply.hasTarget) {
      await locker.writeLane(StintLane.board);
      return BoardExit(reply.url!);
    }
    await locker.writeLane(StintLane.garage);
    return const GarageExit();
  }

  Future<StintExit> _boardAgain() async {
    if (!await watch.hasLink()) return const DarkExit();

    final queued = await locker.takeQueued();
    if (queued != null && queued.isNotEmpty) return BoardExit(queued);

    final held = await locker.target();
    if (held != null && !locker.targetStale) return BoardExit(held);

    await _warmUp();
    if (!await watch.canReachOut()) return const DarkExit();

    await intake.settle(installWait: FlagBook.installWaitShort);
    final reply = await _post();
    if (reply.hasTarget) return BoardExit(reply.url!);
    if (held != null) return BoardExit(held);
    return const DarkExit();
  }

  Future<StintExit> _garageAgain() async {
    if (!await watch.hasLink()) return const GarageExit();
    await _warmUp();
    if (!await watch.canReachOut()) return const GarageExit();

    await intake.settle();
    final reply = await _post();
    if (!reply.hasTarget) return const GarageExit();
    await locker.writeLane(StintLane.board);
    return BoardExit(reply.url!);
  }

  Future<void> _warmUp() async {
    await Future.wait<void>(<Future<void>>[ping.wake(), intake.lift()]);
  }

  Future<BeaconReply> _post({String? pushToken}) async {
    final body = await intake.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: pushToken ?? ping.token,
    );
    return beacon.ask(body);
  }

  /// A cold tap skips the pipeline, so the intake still has to reach the
  /// beacon once in the background for this launch to be accounted for.
  Future<void> _catchUp() async {
    try {
      await Future.wait<void>(<Future<void>>[ping.wake(), intake.settle()]);
      await _post();
    } catch (_) {}
  }

  Future<void> _repostWithToken(String token) async {
    try {
      await _post(pushToken: token);
    } catch (_) {}
  }
}
