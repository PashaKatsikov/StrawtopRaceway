import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the cold-start push destination that `SceneDelegate` stored in
/// UserDefaults (bridged to SharedPreferences via the `flutter.` prefix), then
/// clears it so it is consumed exactly once.
class ColdTapReader {
  static const String _dartKey = 'stw_launch_link';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(_dartKey);
      return value;
    } catch (_) {
      return null;
    }
  }
}
