import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the destination `SceneDelegate` parked in UserDefaults when the app was
/// launched from a cold tap (bridged into preferences by the `flutter.` prefix),
/// then clears it so it is used exactly once.
abstract final class BootLink {
  /// Must stay in sync with `SceneDelegate.entryKey`, minus the `flutter.`
  /// prefix the bridge adds on the Swift side.
  static const String _entryKey = 'rw_grid_entry';

  static Future<String?> take() async {
    if (!Platform.isIOS) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final parked = prefs.getString(_entryKey)?.trim();
      if (parked == null || parked.isEmpty) return null;
      await prefs.remove(_entryKey);
      return parked;
    } catch (_) {
      return null;
    }
  }
}
