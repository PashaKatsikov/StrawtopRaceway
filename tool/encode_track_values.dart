// ignore_for_file: avoid_print
//
// Encodes the pit-flow secrets into obfuscated byte arrays for
// lib/pitwall/config/track_config.dart.
//
// 1. Change `_gritSeed` in lib/pitwall/core/grit_cipher.dart FIRST (kept in
//    sync with the copy below) so the arrays are unique to this app.
// 2. Fill the plaintext map below.
// 3. Run: dart run tool/encode_track_values.dart
// 4. Paste the printed arrays into track_config.dart. The VERIFY line must say
//    every value round-tripped.

import 'dart:typed_data';

const List<int> _gritSeed = <int>[
  0x53, 0x74, 0x77, 0x50, 0x69, 0x74, 0x21, 0x39, 0x34, 0x2A, 0x72, 0x63, 0x77,
];

int _foldSeed() {
  var hash = 0x811c9dc5;
  for (final byte in _gritSeed) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

Uint8List _gritStream(int length) {
  var state = _foldSeed();
  final stream = Uint8List(length);
  for (var index = 0; index < length; index++) {
    state = (state * 1664525 + 1013904223) & 0xffffffff;
    stream[index] = (state >> 23) & 0xff;
  }
  return stream;
}

List<int> mask(String value) {
  final bytes = value.codeUnits;
  final stream = _gritStream(bytes.length);
  return List<int>.generate(
    bytes.length,
    (index) => (((bytes[index] ^ stream[index]) & 0xff) + (index * 31)) & 0xff,
  );
}

String reveal(List<int> encoded) {
  final stream = _gritStream(encoded.length);
  return String.fromCharCodes(
    List<int>.generate(
      encoded.length,
      (index) =>
          (((encoded[index] - (index * 31)) & 0xff) ^ stream[index]) & 0xff,
    ),
  );
}

void main() {
  const values = <String, String>{
    'endpoint': 'https://strawtopraceway.com/config.php',
    'privacy': 'https://strawtopraceway.com/privacy-policy.html',
    'support': 'https://strawtopraceway.com/support.html',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'webkit': '605.1.15',
    'safari': '18.5',
    'safariTail': '604.1',
    'appsFlyerKey': 'UrqWGUP9XweqQfXPx6xYVU',
    'firebaseProject': '554135446133',
  };

  var ok = true;
  for (final entry in values.entries) {
    final encoded = mask(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    if (reveal(encoded) != entry.value) {
      ok = false;
      print('  !! ROUND-TRIP FAILED for ${entry.key}');
    }
  }
  print(ok ? 'VERIFY: all values round-tripped' : 'VERIFY: FAILED');
}
