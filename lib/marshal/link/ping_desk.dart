import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'locker.dart';

@pragma('vm:entry-point')
Future<void> gridQuietMessage(RemoteMessage _) async {}

/// Notification plumbing: token warm-up, foreground presentation, taps on a
/// delivered message and the consent request.
class PingDesk {
  PingDesk(this._locker, {required this.live});

  final Locker _locker;
  final bool live;

  static const int _tokenTries = 8;
  static const int _tokenTriesAfterConsent = 10;
  static const Duration _tokenGap = Duration(milliseconds: 420);
  static const Duration _openingGap = Duration(seconds: 6);

  /// Payload keys the backend may use for the destination — server contract,
  /// mirrored in `SceneDelegate`.
  static const List<String> _directKeys = <String>[
    'deep_link',
    'target',
    'url',
    'deeplink',
    'link',
  ];
  static const List<String> _nestedKeys = <String>['payload', 'data'];

  FirebaseMessaging? _fcm;
  Future<void>? _wakeFuture;
  Future<bool>? _consentFuture;
  String? _token;

  void Function(String url)? onTarget;
  void Function(String token)? onToken;

  String? get token => _token;

  Future<void> wake() => _wakeFuture ??= _wake();

  Future<void> _wake() async {
    if (!live) return;
    final fcm = FirebaseMessaging.instance;
    _fcm = fcm;
    final opening = await fcm.getInitialMessage().timeout(
      _openingGap,
      onTimeout: () => null,
    );
    final openingTarget = opening == null ? null : _dig(opening.data);
    if (openingTarget != null) await _locker.queueTarget(openingTarget);

    FirebaseMessaging.onBackgroundMessage(gridQuietMessage);
    await fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    fcm.onTokenRefresh.listen((value) {
      _token = value;
      onToken?.call(value);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final target = _dig(message.data);
      if (target == null) return;
      final sink = onTarget;
      if (sink == null) {
        _locker.queueTarget(target);
      } else {
        sink(target);
      }
    });
    await _settleApns();
    _token = await fcm.getToken();
  }

  String? _dig(Map<String, dynamic> payload) {
    for (final key in _directKeys) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    for (final key in _nestedKeys) {
      final branch = payload[key];
      if (branch is Map) {
        final found = _dig(Map<String, dynamic>.from(branch));
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _settleApns({int tries = _tokenTries}) async {
    final fcm = _fcm;
    if (fcm == null) return;
    for (var attempt = 0; attempt < tries; attempt++) {
      try {
        if ((await fcm.getAPNSToken())?.isNotEmpty ?? false) return;
      } catch (_) {}
      await Future<void>.delayed(_tokenGap);
    }
  }

  Future<bool> mayAskConsent() async {
    if (!live || _locker.pingBlockedBySystem) return false;
    final fcm = _fcm;
    if (fcm == null) return false;
    final state = (await fcm.getNotificationSettings()).authorizationStatus;
    if (state == AuthorizationStatus.denied) {
      await _locker.markPingBlocked();
      return false;
    }
    return state == AuthorizationStatus.notDetermined ||
        state == AuthorizationStatus.provisional;
  }

  Future<bool> askConsent() => _consentFuture ??= _askConsent().whenComplete(
    () => _consentFuture = null,
  );

  Future<bool> _askConsent() async {
    final fcm = _fcm;
    if (!live || fcm == null) return false;
    final outcome = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted =
        outcome.authorizationStatus == AuthorizationStatus.authorized ||
        outcome.authorizationStatus == AuthorizationStatus.provisional;
    await _locker.writePingGranted(granted);
    if (!granted &&
        outcome.authorizationStatus == AuthorizationStatus.denied) {
      await _locker.markPingBlocked();
    }
    if (granted) {
      await _settleApns(tries: _tokenTriesAfterConsent);
      _token = await fcm.getToken();
      final fresh = _token;
      if (fresh != null && fresh.isNotEmpty) onToken?.call(fresh);
    }
    return granted;
  }
}
