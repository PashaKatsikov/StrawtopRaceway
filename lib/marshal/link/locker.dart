import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stint_types.dart';

/// Local state for the marshal layer: the lane verdict, cached and queued
/// targets, notification consent and the prompt cooldown. Targets live in the
/// Keychain, everything else in preferences.
class Locker {
  static const String _laneKey = 'rw.grid.lane';
  static const String _ttlKey = 'rw.grid.ttl';
  static const String _pingNextKey = 'rw.grid.ping.next';
  static const String _pingOnKey = 'rw.grid.ping.on';
  static const String _pingBlockedKey = 'rw.grid.ping.blocked';
  static const String _targetKey = 'rw.grid.board.target';
  static const String _queuedKey = 'rw.grid.board.queued';

  /// Keys used before the storage namespace changed. Their values are carried
  /// over once so an update never resets a device that already has a lane.
  static const Map<String, String> _priorPrefs = <String, String>{
    'stw.pit.route': _laneKey,
    'stw.pit.expiry': _ttlKey,
    'stw.pit.invite.after': _pingNextKey,
    'stw.pit.push.allowed': _pingOnKey,
    'stw.pit.push.os_denied': _pingBlockedKey,
  };
  static const Map<String, String> _priorSecure = <String, String>{
    'stw.pit.secure.destination': _targetKey,
    'stw.pit.secure.pending': _queuedKey,
  };

  final FlutterSecureStorage _safe = const FlutterSecureStorage();
  late SharedPreferences _prefs;

  Future<void> open() async {
    _prefs = await SharedPreferences.getInstance();
    await _carryPrefs();
    await _carrySecure();
  }

  Future<void> _carryPrefs() async {
    for (final pair in _priorPrefs.entries) {
      final value = _prefs.get(pair.key);
      if (value == null) continue;
      if (_prefs.get(pair.value) == null) {
        switch (value) {
          case final String text:
            await _prefs.setString(pair.value, text);
          case final int number:
            await _prefs.setInt(pair.value, number);
          case final bool flag:
            await _prefs.setBool(pair.value, flag);
          default:
            break;
        }
      }
      await _prefs.remove(pair.key);
    }
  }

  Future<void> _carrySecure() async {
    for (final pair in _priorSecure.entries) {
      try {
        final value = await _safe.read(key: pair.key);
        if (value == null) continue;
        if (await _safe.read(key: pair.value) == null) {
          await _safe.write(key: pair.value, value: value);
        }
        await _safe.delete(key: pair.key);
      } catch (_) {
        // Keychain unavailable: fall through, the layer works without history.
      }
    }
  }

  StintLane get lane => StintLane.read(_prefs.getString(_laneKey));

  Future<void> writeLane(StintLane lane) =>
      _prefs.setString(_laneKey, lane.stored);

  Future<String?> target() async {
    try {
      return await _safe.read(key: _targetKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> holdTarget(String url, int? expiresAt) async {
    try {
      await _safe.write(key: _targetKey, value: url);
      if (expiresAt != null) await _prefs.setInt(_ttlKey, expiresAt);
    } catch (_) {}
  }

  bool get targetStale {
    final ttl = _prefs.getInt(_ttlKey);
    return ttl == null || _nowSeconds >= ttl;
  }

  Future<void> queueTarget(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    try {
      await _safe.write(key: _queuedKey, value: trimmed);
    } catch (_) {}
  }

  Future<String?> takeQueued() async {
    try {
      final value = await _safe.read(key: _queuedKey);
      if (value != null) await _safe.delete(key: _queuedKey);
      return value;
    } catch (_) {
      return null;
    }
  }

  bool get pingGranted => _prefs.getBool(_pingOnKey) ?? false;
  bool get pingBlockedBySystem => _prefs.getBool(_pingBlockedKey) ?? false;

  Future<void> writePingGranted(bool value) =>
      _prefs.setBool(_pingOnKey, value);

  Future<void> markPingBlocked() => _prefs.setBool(_pingBlockedKey, true);

  bool get mayOfferPing {
    if (pingGranted || pingBlockedBySystem) return false;
    final next = _prefs.getInt(_pingNextKey);
    return next == null || _nowSeconds >= next;
  }

  Future<void> quietPing(int untilEpochSeconds) =>
      _prefs.setInt(_pingNextKey, untilEpochSeconds);

  int get _nowSeconds => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
