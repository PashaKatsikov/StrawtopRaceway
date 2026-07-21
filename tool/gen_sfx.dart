// Generates short 16-bit PCM WAV sound effects into assets/audio/.
// Run once with:  dart run tool/gen_sfx.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 22050;

void main() {
  final dir = Directory('assets/audio');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  _write('sfx_click.wav', _click());
  _write('sfx_coin.wav', _coin());
  _write('sfx_star.wav', _star());
  _write('sfx_hit.wav', _hit());
  _write('sfx_power.wav', _power());
  _write('sfx_win.wav', _win());
  _write('sfx_lose.wav', _lose());
  _write('sfx_go.wav', _go());
  stdout.writeln('Done generating SFX.');
}

void _write(String name, List<double> samples) {
  final file = File('assets/audio/$name');
  file.writeAsBytesSync(_encodeWav(samples));
  stdout.writeln('  wrote $name (${samples.length} samples)');
}

// ---- Sound designs --------------------------------------------------------

List<double> _click() =>
    _tone(660, 0.06, wave: _Wave.square, vol: 0.35, decay: 18);

List<double> _coin() => _concat([
      _tone(988, 0.05, vol: 0.7, decay: 9),
      _tone(1480, 0.12, vol: 0.7, decay: 7),
    ]);

List<double> _star() => _concat([
      _tone(1180, 0.05, vol: 0.35, decay: 10),
      _tone(1560, 0.07, vol: 0.35, decay: 10),
      _tone(1980, 0.09, vol: 0.3, decay: 9),
    ]);

List<double> _hit() {
  // Noisy thud with a falling tone.
  final rnd = Random(7);
  final len = (sampleRate * 0.18).round();
  final out = List<double>.filled(len, 0);
  for (int i = 0; i < len; i++) {
    final t = i / sampleRate;
    final env = exp(-t * 16);
    final freq = 260 - 700 * t;
    final tone = sin(2 * pi * freq.clamp(60, 400) * t);
    final noise = (rnd.nextDouble() * 2 - 1) * 0.5;
    out[i] = ((tone * 0.6 + noise) * env * 0.5).clamp(-1, 1);
  }
  return out;
}

List<double> _power() {
  // Rising sweep.
  final len = (sampleRate * 0.28).round();
  final out = List<double>.filled(len, 0);
  double phase = 0;
  for (int i = 0; i < len; i++) {
    final t = i / sampleRate;
    final freq = 420 + 1100 * (t / 0.28);
    phase += 2 * pi * freq / sampleRate;
    final env = sin(pi * (t / 0.28)).clamp(0.0, 1.0);
    out[i] = sin(phase) * env * 0.4;
  }
  return out;
}

List<double> _win() => _concat([
      _tone(523, 0.12, vol: 0.4, decay: 4),
      _tone(659, 0.12, vol: 0.4, decay: 4),
      _tone(784, 0.12, vol: 0.4, decay: 4),
      _tone(1047, 0.28, vol: 0.45, decay: 3),
    ]);

List<double> _lose() => _concat([
      _tone(440, 0.14, vol: 0.4, decay: 4, wave: _Wave.square),
      _tone(349, 0.14, vol: 0.4, decay: 4, wave: _Wave.square),
      _tone(262, 0.30, vol: 0.4, decay: 3, wave: _Wave.square),
    ]);

List<double> _go() => _concat([
      _tone(784, 0.10, vol: 0.4, decay: 6),
      _tone(1047, 0.20, vol: 0.45, decay: 4),
    ]);

// ---- Synth helpers --------------------------------------------------------

enum _Wave { sine, square }

List<double> _tone(double freq, double seconds,
    {double vol = 0.4, double decay = 6, _Wave wave = _Wave.sine}) {
  final len = (sampleRate * seconds).round();
  final out = List<double>.filled(len, 0);
  for (int i = 0; i < len; i++) {
    final t = i / sampleRate;
    final env = exp(-t * decay);
    final s = sin(2 * pi * freq * t);
    final v = wave == _Wave.square ? (s >= 0 ? 1.0 : -1.0) : s;
    out[i] = v * env * vol;
  }
  return out;
}

List<double> _concat(List<List<double>> parts) {
  final out = <double>[];
  for (final p in parts) {
    out.addAll(p);
  }
  return out;
}

Uint8List _encodeWav(List<double> samples) {
  final numSamples = samples.length;
  final byteRate = sampleRate * 2; // mono, 16-bit
  final dataSize = numSamples * 2;
  final buffer = BytesBuilder();

  void writeString(String s) => buffer.add(s.codeUnits);
  void writeUint32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    buffer.add(b.buffer.asUint8List());
  }

  void writeUint16(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    buffer.add(b.buffer.asUint8List());
  }

  writeString('RIFF');
  writeUint32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(1); // mono
  writeUint32(sampleRate);
  writeUint32(byteRate);
  writeUint16(2); // block align
  writeUint16(16); // bits per sample
  writeString('data');
  writeUint32(dataSize);

  final pcm = ByteData(dataSize);
  for (int i = 0; i < numSamples; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    pcm.setInt16(i * 2, v, Endian.little);
  }
  buffer.add(pcm.buffer.asUint8List());
  return buffer.toBytes();
}
