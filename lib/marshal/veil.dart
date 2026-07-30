import 'dart:convert';

/// Unpacks a value stored by [FlagBook] in the form produced by
/// `dart run tool/pack_marshal_values.dart`.
///
/// The storage shape is ordinary base64 (`dart:convert`) over bytes folded with
/// a position-keyed XOR against [_pepper]; the stride keeps one pepper byte
/// from lining up with the same offset in every value. Keep [_pepper] and the
/// stride in sync with the packer tool — changing either invalidates every
/// packed string in [FlagBook].
const String _pepper = 'com.strawtop.racewaygame+grid5A';

int _keyByte(List<int> key, int index) => key[(index * 5 + 11) % key.length];

String unveil(String packed) {
  if (packed.isEmpty) return '';
  final key = utf8.encode(_pepper);
  final raw = base64Decode(packed);
  return utf8.decode(
    List<int>.generate(raw.length, (i) => raw[i] ^ _keyByte(key, i)),
  );
}
