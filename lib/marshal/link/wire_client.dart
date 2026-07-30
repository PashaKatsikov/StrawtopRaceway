import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../flag_book.dart';

/// HTTP client that presents the same browser identity as the board view, so
/// the backend always sees one consistent caller. Every fragment of that
/// identity is assembled at runtime from packed values.
class WireClient extends http.BaseClient {
  final http.Client _pipe = http.Client();
  String? _identity;

  Future<void> prime() async {
    if (!Platform.isIOS) {
      _identity = _compose(FlagBook.uaRelease);
      return;
    }
    try {
      final device = await DeviceInfoPlugin().iosInfo;
      _identity = _compose(_release(device.systemVersion));
    } catch (_) {
      _identity = _compose(FlagBook.uaRelease);
    }
  }

  String get identity => _identity ??= _compose(FlagBook.uaRelease);

  /// Keeps at most three numeric components and refuses anything the partner
  /// backend would treat as an outdated client.
  String _release(String raw) {
    final parts = raw
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .take(3)
        .toList(growable: false);
    if (parts.isEmpty || parts.first < 18) return FlagBook.uaRelease;
    return parts.join('.');
  }

  String _compose(String release) {
    final buffer = StringBuffer()
      ..write(FlagBook.uaOpen)
      ..write(release.replaceAll('.', '_'))
      ..write(FlagBook.uaKernel)
      ..write(FlagBook.uaEngine)
      ..write(FlagBook.uaLayout)
      ..write(FlagBook.uaRelease)
      ..write(FlagBook.uaDevice)
      ..write(FlagBook.uaTail);
    return buffer.toString();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => identity);
    return _pipe.send(request);
  }

  @override
  void close() => _pipe.close();
}
