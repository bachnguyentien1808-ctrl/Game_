// Sinh am thanh hieu ung tong hop (WAV 16-bit mono 22050 Hz) vao assets/sfx/.
// Chay: dart run tools/gen_sfx.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _rate = 22050;

/// Mot not: tan so dau/cuoi (truot), thoi diem bat dau, do dai (giay).
class _Note {
  const _Note(
    this.f0,
    this.start,
    this.len, {
    double? f1,
    this.gain = 1,
    this.decay = 6,
  }) : f1 = f1 ?? f0;

  final double f0;
  final double f1;
  final double start;
  final double len;
  final double gain;

  /// He so suy giam mu (lon = tat nhanh).
  final double decay;
}

Float64List _render(double total, List<_Note> notes, {double noise = 0}) {
  final n = (total * _rate).round();
  final out = Float64List(n);
  final rng = Random(7);
  for (final note in notes) {
    final s0 = (note.start * _rate).round();
    final len = (note.len * _rate).round();
    var phase = 0.0;
    for (var i = 0; i < len && s0 + i < n; i++) {
      final t = i / len;
      final f = note.f0 + (note.f1 - note.f0) * t;
      phase += 2 * pi * f / _rate;
      // Envelope: len 4ms, roi suy giam mu, tat muot o cuoi.
      final attack = min(1, i / (_rate * 0.004));
      final env = attack * exp(-note.decay * t) * (1 - pow(t, 8));
      // Sin + chut hoa am bac 2 cho am am, khong gat.
      final v = sin(phase) + 0.18 * sin(2 * phase) + 0.06 * sin(3 * phase);
      out[s0 + i] += v * env * note.gain;
    }
  }
  if (noise > 0) {
    var lp = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / n;
      lp += 0.15 * ((rng.nextDouble() * 2 - 1) - lp);
      out[i] += lp * noise * sin(pi * t);
    }
  }
  return out;
}

Uint8List _wav(Float64List s, {double peak = 0.42}) {
  var m = 1e-9;
  for (final v in s) {
    m = max(m, v.abs());
  }
  final pcm = Int16List(s.length);
  for (var i = 0; i < s.length; i++) {
    pcm[i] = (s[i] / m * peak * 32767).round().clamp(-32768, 32767);
  }
  final data = pcm.buffer.asUint8List();
  final b = BytesBuilder()
    ..add('RIFF'.codeUnits)
    ..add(_u32(36 + data.length))
    ..add('WAVEfmt '.codeUnits)
    ..add(_u32(16))
    ..add(_u16(1))
    ..add(_u16(1))
    ..add(_u32(_rate))
    ..add(_u32(_rate * 2))
    ..add(_u16(2))
    ..add(_u16(16))
    ..add('data'.codeUnits)
    ..add(_u32(data.length))
    ..add(data);
  return b.toBytes();
}

List<int> _u32(int v) =>
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
List<int> _u16(int v) =>
    (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List();

final _sounds = <String, (Float64List, double)>{
  'tap': (_render(0.08, const [_Note(1046, 0, 0.08, decay: 9)]), 0.30),
  'place': (
    _render(0.11, const [_Note(700, 0, 0.11, f1: 560, decay: 7)]),
    0.38,
  ),
  'erase': (
    _render(0.14, const [_Note(520, 0, 0.14, f1: 260, decay: 5)]),
    0.32,
  ),
  'merge': (
    _render(0.17, const [
      _Note(523, 0, 0.09, f1: 600, decay: 5),
      _Note(784, 0.06, 0.11, f1: 830),
    ]),
    0.40,
  ),
  'flip': (
    _render(0.12, const [
      _Note(320, 0, 0.12, f1: 760, gain: 0.5, decay: 5),
    ], noise: 0.9),
    0.30,
  ),
  'match': (
    _render(0.28, const [
      _Note(659, 0, 0.14, decay: 5),
      _Note(988, 0.1, 0.18, decay: 5),
    ]),
    0.40,
  ),
  'success': (
    _render(0.42, const [
      _Note(523, 0, 0.18, decay: 4),
      _Note(659, 0.09, 0.18, decay: 4),
      _Note(784, 0.18, 0.24, decay: 4),
    ]),
    0.42,
  ),
  'error': (
    _render(0.22, const [
      _Note(233, 0, 0.1, f1: 210, decay: 4),
      _Note(208, 0.11, 0.11, f1: 185, decay: 4),
    ]),
    0.36,
  ),
  'win': (
    _render(0.6, const [
      _Note(523, 0, 0.2, decay: 3),
      _Note(659, 0.1, 0.2, decay: 3),
      _Note(784, 0.2, 0.2, decay: 3),
      _Note(1046, 0.3, 0.3, decay: 3),
      _Note(784, 0.3, 0.3, gain: 0.4, decay: 3),
    ]),
    0.45,
  ),
};

void main() {
  final dir = Directory('assets/sfx')..createSync(recursive: true);
  for (final e in _sounds.entries) {
    final f = File('${dir.path}/${e.key}.wav')
      ..writeAsBytesSync(_wav(e.value.$1, peak: e.value.$2));
    print('${f.path} ${f.lengthSync()} byte');
  }
}
