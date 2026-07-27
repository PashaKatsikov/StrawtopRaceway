import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/track_config.dart';

/// HTTP client that forges a real Mobile-Safari User-Agent and applies it to
/// every request. The same string is reused by the WebView so the partner
/// backend sees one consistent identity.
class PitAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _agentString;

  Future<void> warmUp() async {
    try {
      if (!Platform.isIOS) {
        _agentString = _fallback();
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _agentString = _mobileSafari(_normalizedIos(info.systemVersion));
    } catch (_) {
      _agentString = _fallback();
    }
  }

  String get userAgent => _agentString ?? _fallback();

  String _normalizedIos(String raw) {
    final parts = raw
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .take(3)
        .toList();
    if (parts.isEmpty || parts.first < 18) return '18.5';
    return parts.join('.');
  }

  // GAME THEME CATEGORY: crash (no appid/appname suffix).
  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS $cpu like Mac OS X) '
        'AppleWebKit/${TrackConfig.webKitVersion} (KHTML, like Gecko) '
        'Version/${TrackConfig.safariVersion} Mobile/15E148 '
        'Safari/${TrackConfig.safariTail}';
  }

  String _fallback() => _mobileSafari('18.5');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
