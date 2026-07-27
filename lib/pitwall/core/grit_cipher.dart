import 'dart:typed_data';

/// Position-keyed obfuscation for the pit-flow secrets.
///
/// The keystream is derived from [_gritSeed] via an FNV-1a fold seeding a
/// linear-congruential generator, then mixed into each byte with an additive
/// position term. This is intentionally a different construction from any
/// sibling app — the machine code, the seed and the byte tables all differ.
///
/// Keep [_gritSeed] unique to THIS project and re-run
/// `dart run tool/encode_track_values.dart` after any change to it.
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

/// Decodes a byte array produced by `tool/encode_track_values.dart`.
String revealGrit(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final stream = _gritStream(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var index = 0; index < encoded.length; index++) {
    plain[index] = (((encoded[index] - (index * 31)) & 0xff) ^ stream[index]) & 0xff;
  }
  return String.fromCharCodes(plain);
}
