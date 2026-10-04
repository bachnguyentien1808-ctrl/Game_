// Ve icon app Puzzle Hub (manh ghep trang tren nen seed) ra assets/icon/.
// Chay: dart run tools/gen_icon.dart
// Roi: dart run flutter_launcher_icons && dart run flutter_native_splash:create
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

// Mau seed mac dinh (AppTheme.defaultSeed 0xFF4F46E5) va sac dam hon.
const _top = (99, 102, 241);
const _bottom = (67, 56, 202);

/// Hinh manh ghep trong toa do chuan hoa 0..1 (tam ~0.5, 0.5).
bool _inPiece(double px, double py) {
  // Doi ve tam cho can giua hop bao.
  final x = px + 0.045;
  final y = py + 0.01;
  bool circle(double cx, double cy, double r) =>
      (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r;
  bool roundRect(double l, double t, double r, double b, double rad) {
    if (x < l || x > r || y < t || y > b) return false;
    final cx = x.clamp(l + rad, r - rad);
    final cy = y.clamp(t + rad, b - rad);
    return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= rad * rad;
  }

  final body = roundRect(0.30, 0.33, 0.70, 0.73, 0.05);
  final knobs = circle(0.5, 0.29, 0.085) || circle(0.74, 0.53, 0.085);
  final holes = circle(0.30, 0.53, 0.07) || circle(0.5, 0.73, 0.07);
  return (body || knobs) && !holes;
}

/// Do phu (0..1) cua manh ghep tai pixel, lay mau 4x4 de khu rang cua.
double _coverage(int px, int py, int size, double scale) {
  var hit = 0;
  for (var sy = 0; sy < 4; sy++) {
    for (var sx = 0; sx < 4; sx++) {
      final x = (px + (sx + 0.5) / 4) / size;
      final y = (py + (sy + 0.5) / 4) / size;
      // Thu phong quanh tam.
      if (_inPiece(0.5 + (x - 0.5) / scale, 0.5 + (y - 0.5) / scale)) hit++;
    }
  }
  return hit / 16;
}

img.Image _draw(int size, {required bool background, double scale = 1}) {
  final im = img.Image(width: size, height: size, numChannels: 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final c = _coverage(x, y, size, scale);
      if (background) {
        final t = (x + y) / (2 * size);
        final r = _top.$1 + (_bottom.$1 - _top.$1) * t;
        final g = _top.$2 + (_bottom.$2 - _top.$2) * t;
        final b = _top.$3 + (_bottom.$3 - _top.$3) * t;
        im.setPixelRgba(
          x,
          y,
          (r + (255 - r) * c).round(),
          (g + (255 - g) * c).round(),
          (b + (255 - b) * c).round(),
          255,
        );
      } else {
        im.setPixelRgba(x, y, 255, 255, 255, (255 * c).round());
      }
    }
  }
  return im;
}

void main() {
  final dir = Directory('assets/icon')..createSync(recursive: true);
  final out = <String, img.Image>{
    // Icon day du (iOS/web/Windows/macOS): nen gradient + manh ghep.
    'icon.png': _draw(1024, background: true, scale: 1.25),
    // Lop truoc icon thich ung Android (vung an toan 66%).
    'foreground.png': _draw(1024, background: false, scale: 0.95),
    // Splash: manh ghep trang tren nen trong suot.
    'splash.png': _draw(768, background: false, scale: 1.1),
  };
  for (final e in out.entries) {
    final f = File('${dir.path}/${e.key}')
      ..writeAsBytesSync(img.encodePng(e.value));
    print('${f.path} ${f.lengthSync()} byte');
  }
  print('Mau nen: #${_hex(_bottom)} / #${_hex(_top)}');
}

String _hex((int, int, int) c) => [
  c.$1,
  c.$2,
  c.$3,
].map((v) => max(0, v).toRadixString(16).padLeft(2, '0')).join();
