// ignore_for_file: avoid_print
//
// Packs the marshal-layer values into the base64 form that
// lib/marshal/flag_book.dart stores.
//
// 1. Keep `_pepper` below identical to the one in lib/marshal/veil.dart.
// 2. Fill the plaintext map in main().
// 3. Run: dart run tool/pack_marshal_values.dart
// 4. Copy the printed strings into flag_book.dart. The VERIFY line must
//    confirm every value unpacked back to its exact plaintext.
//
// Public URLs (privacy policy, support) are deliberately NOT packed — they are
// published in App Store Connect anyway, so folding them here would only add
// decoder traffic for no benefit.

import 'dart:convert';

const String _pepper = 'com.strawtop.racewaygame+grid5A';

int _keyByte(List<int> key, int index) => key[(index * 5 + 11) % key.length];

String pack(String value) {
  final key = utf8.encode(_pepper);
  final bytes = utf8.encode(value);
  return base64Encode(
    List<int>.generate(bytes.length, (i) => bytes[i] ^ _keyByte(key, i)),
  );
}

String unpack(String packed) {
  final key = utf8.encode(_pepper);
  final raw = base64Decode(packed);
  return utf8.decode(
    List<int>.generate(raw.length, (i) => raw[i] ^ _keyByte(key, i)),
  );
}

void main() {
  const values = <String, String>{
    'beaconUrl': 'https://strawtopraceway.com/config.php',
    'intakeLookup': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'intakeKey': 'UrqWGUP9XweqQfXPx6xYVU',
    'signalProject': '554135446133',
    // User-Agent fragments, including the scaffolding: no part of a browser
    // identity may sit in the binary as a readable literal.
    'uaOpen': 'Mozilla/5.0 (iPhone; CPU iPhone OS ',
    'uaKernel': ' like Mac OS X) AppleWebKit/',
    'uaEngine': '605.1.15',
    'uaLayout': ' (KHTML, like Gecko) Version/',
    'uaRelease': '18.5',
    'uaDevice': ' Mobile/15E148 Safari/',
    'uaTail': '604.1',
  };

  var ok = true;
  for (final entry in values.entries) {
    final packed = pack(entry.value);
    print("${entry.key}: '$packed'");
    if (unpack(packed) != entry.value) {
      ok = false;
      print('  !! ROUND-TRIP FAILED for ${entry.key}');
    }
  }
  print(ok ? 'VERIFY: all values round-tripped' : 'VERIFY: FAILED');
}
