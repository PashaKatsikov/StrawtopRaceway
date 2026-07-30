import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Interface state plus a real reachability check.
class NetWatch {
  /// Resolved instead of our own domain: a VPN or a freshly registered app
  /// domain must never be able to fake an offline verdict.
  static const List<String> _anchors = <String>[
    'www.microsoft.com',
    'www.msftconnecttest.com',
  ];
  static const Duration _resolveCap = Duration(milliseconds: 2600);

  final Connectivity _radio = Connectivity();

  Future<bool> hasLink() async {
    try {
      final states = await _radio.checkConnectivity();
      return states.any((state) => state != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<bool> canReachOut() async {
    if (!await hasLink()) return false;
    for (final anchor in _anchors) {
      if (await _resolves(anchor)) return true;
    }
    return false;
  }

  Future<bool> _resolves(String host) async {
    try {
      final records = await InternetAddress.lookup(host).timeout(_resolveCap);
      return records.any((record) => record.rawAddress.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get shifts => _radio.onConnectivityChanged;
}
