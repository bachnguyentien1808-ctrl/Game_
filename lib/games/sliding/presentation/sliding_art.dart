import 'dart:math';

import 'package:flutter/material.dart';

/// Tranh sinh bang canvas cho che do Anh cua Xep so. Moi tranh ve tren
/// khung vuong [Size]; o co chi lay mot phan cua tranh.
abstract final class SlidingArt {
  static const names = [
    'Hoàng hôn',
    'Hình học',
    'Hoạ tiết',
    'Phong cảnh',
    'Đêm sao',
  ];

  static int get count => names.length;

  static void paint(Canvas canvas, Size sz, int art) {
    switch (art % count) {
      case 0:
        _sunset(canvas, sz);
      case 1:
        _geometry(canvas, sz);
      case 2:
        _pattern(canvas, sz);
      case 3:
        _landscape(canvas, sz);
      default:
        _night(canvas, sz);
    }
  }

  static Paint _fill(Color c) => Paint()..color = c;

  static Paint _grad(Rect r, List<Color> colors, {List<double>? stops}) =>
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(r);

  static void _sunset(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(
      r,
      _grad(
        r,
        const [
          Color(0xFF2B1B5A),
          Color(0xFF8E2E7A),
          Color(0xFFF2683C),
          Color(0xFFFFC857),
        ],
        stops: const [0, .35, .65, .78],
      ),
    );
    final sun = Offset(s.width * .5, s.height * .66);
    c.drawCircle(
      sun,
      s.width * .2,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF3B0), Color(0xFFFFB347)],
        ).createShader(Rect.fromCircle(center: sun, radius: s.width * .2)),
    );
    final seaTop = s.height * .72;
    final sea = Rect.fromLTWH(0, seaTop, s.width, s.height - seaTop);
    c.drawRect(sea, _grad(sea, const [Color(0xFFB3472F), Color(0xFF2A1740)]));
    for (var i = 0; i < 9; i++) {
      final y = seaTop + (i + .6) * sea.height / 9;
      final w = s.width * (.34 - i * .028);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(s.width * .5 + (i.isEven ? 6 : -6), y),
            width: w.clamp(8, s.width),
            height: sea.height / 22,
          ),
          const Radius.circular(8),
        ),
        _fill(const Color(0xFFFFD27A).withValues(alpha: .75 - i * .06)),
      );
    }
    for (var i = 0; i < 5; i++) {
      final y = s.height * (.18 + i * .07);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            s.width * (.1 + (i * .23) % .6),
            y,
            s.width * (.22 + (i % 2) * .1),
            s.height * .018,
          ),
          const Radius.circular(8),
        ),
        _fill(Colors.white.withValues(alpha: .18)),
      );
    }
  }

  static void _geometry(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    c.drawRect(Offset.zero & s, _fill(const Color(0xFFF6EBD9)));
    c.drawCircle(
      Offset(w * .3, h * .32),
      w * .24,
      _fill(const Color(0xFFE4572E)),
    );
    c.drawRect(
      Rect.fromLTWH(w * .52, h * .08, w * .38, w * .38),
      _fill(const Color(0xFF17BEBB)),
    );
    final tri = Path()
      ..moveTo(w * .08, h * .92)
      ..lineTo(w * .46, h * .52)
      ..lineTo(w * .84, h * .92)
      ..close();
    c.drawPath(tri, _fill(const Color(0xFF2E294E)));
    c.drawCircle(
      Offset(w * .72, h * .7),
      w * .13,
      _fill(const Color(0xFFFFC914)),
    );
    c.drawArc(
      Rect.fromCircle(center: Offset(w * .3, h * .32), radius: w * .34),
      pi,
      pi * .8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .035
        ..color = const Color(0xFF2E294E),
    );
    c.drawRect(
      Rect.fromLTWH(w * .06, h * .06, w * .12, w * .12),
      _fill(const Color(0xFFFFC914)),
    );
    final tri2 = Path()
      ..moveTo(w * .62, h * .5)
      ..lineTo(w * .92, h * .5)
      ..lineTo(w * .92, h * .74)
      ..close();
    c.drawPath(tri2, _fill(const Color(0xFFE4572E)));
    c.drawLine(
      Offset(w * .1, h * .62),
      Offset(w * .4, h * .62),
      Paint()
        ..strokeWidth = w * .03
        ..color = const Color(0xFF17BEBB),
    );
  }

  static void _pattern(Canvas c, Size s) {
    const n = 6;
    final cell = s.width / n;
    c.drawRect(Offset.zero & s, _fill(const Color(0xFFFFF1D6)));
    final a = _fill(const Color(0xFF0F7173));
    final b = _fill(const Color(0xFFEF6F6C));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * .2
      ..color = const Color(0xFF2B2D42);
    for (var r = 0; r < n; r++) {
      for (var col = 0; col < n; col++) {
        final o = Offset(col * cell, r * cell);
        final even = (r + col).isEven;
        c.drawRect(Rect.fromLTWH(o.dx, o.dy, cell, cell), even ? a : b);
        final ctr = o + Offset(even ? 0 : cell, 0);
        c.drawArc(
          Rect.fromCircle(center: ctr, radius: cell * .5),
          even ? 0 : pi / 2,
          pi / 2,
          false,
          stroke,
        );
        c.drawCircle(
          o + Offset(cell * .5, cell * .5),
          cell * .12,
          _fill(Colors.white.withValues(alpha: .85)),
        );
      }
    }
  }

  static void _landscape(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    final r = Offset.zero & s;
    c.drawRect(
      r,
      _grad(
        r,
        const [Color(0xFF5BB5F0), Color(0xFFBFE6FA), Color(0xFFFFF4D6)],
        stops: const [0, .5, .62],
      ),
    );
    c.drawCircle(
      Offset(w * .8, h * .16),
      w * .075,
      _fill(const Color(0xFFFFE066)),
    );
    void cloud(double x, double y, double k) {
      final p = _fill(Colors.white.withValues(alpha: .9));
      c.drawOval(
        Rect.fromCenter(
          center: Offset(w * x, h * y),
          width: w * .22 * k,
          height: h * .05 * k,
        ),
        p,
      );
      c.drawOval(
        Rect.fromCenter(
          center: Offset(w * (x - .05 * k), h * (y + .01)),
          width: w * .14 * k,
          height: h * .045 * k,
        ),
        p,
      );
      c.drawOval(
        Rect.fromCenter(
          center: Offset(w * (x + .06 * k), h * (y + .012)),
          width: w * .13 * k,
          height: h * .04 * k,
        ),
        p,
      );
    }

    cloud(.25, .13, 1);
    cloud(.58, .24, .8);
    final far = Path()
      ..moveTo(0, h * .62)
      ..lineTo(w * .2, h * .4)
      ..lineTo(w * .36, h * .54)
      ..lineTo(w * .55, h * .3)
      ..lineTo(w * .78, h * .56)
      ..lineTo(w * .9, h * .46)
      ..lineTo(w, h * .58)
      ..lineTo(w, h * .66)
      ..lineTo(0, h * .66)
      ..close();
    c.drawPath(far, _fill(const Color(0xFF7C93C3)));
    final snow = Path()
      ..moveTo(w * .55, h * .3)
      ..lineTo(w * .49, h * .385)
      ..lineTo(w * .53, h * .37)
      ..lineTo(w * .56, h * .4)
      ..lineTo(w * .6, h * .37)
      ..lineTo(w * .62, h * .385)
      ..close();
    c.drawPath(snow, _fill(Colors.white));
    final hill = Path()
      ..moveTo(0, h * .7)
      ..quadraticBezierTo(w * .3, h * .56, w * .6, h * .68)
      ..quadraticBezierTo(w * .85, h * .76, w, h * .64)
      ..lineTo(w, h * .72)
      ..lineTo(0, h * .72)
      ..close();
    c.drawPath(hill, _fill(const Color(0xFF4F9D69)));
    final lake = Rect.fromLTWH(0, h * .7, w, h * .16);
    c.drawRect(lake, _grad(lake, const [Color(0xFF4DA3C7), Color(0xFF2A7FA6)]));
    for (var i = 0; i < 4; i++) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            w * (.12 + i * .2),
            h * (.73 + i * .028),
            w * .16,
            h * .008,
          ),
          const Radius.circular(4),
        ),
        _fill(Colors.white.withValues(alpha: .5)),
      );
    }
    final ground = Rect.fromLTWH(0, h * .86, w, h * .14);
    c.drawRect(
      ground,
      _grad(ground, const [Color(0xFF3F7D4E), Color(0xFF2A5A37)]),
    );
    void pine(double x, double base, double k) {
      c.drawRect(
        Rect.fromLTWH(
          w * x - w * .006 * k,
          h * base - h * .03 * k,
          w * .012 * k,
          h * .04 * k,
        ),
        _fill(const Color(0xFF5B3A29)),
      );
      for (var i = 0; i < 3; i++) {
        final top = base - (.2 - i * .055) * k;
        final p = Path()
          ..moveTo(w * x, h * top)
          ..lineTo(w * x - w * (.045 + i * .02) * k, h * (top + .095 * k))
          ..lineTo(w * x + w * (.045 + i * .02) * k, h * (top + .095 * k))
          ..close();
        c.drawPath(p, _fill(const Color(0xFF1F6B3A)));
      }
    }

    pine(.12, .93, 1.15);
    pine(.25, .96, 1);
    pine(.86, .95, 1.1);
    pine(.74, .98, .85);
  }

  static void _night(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    final r = Offset.zero & s;
    c.drawRect(
      r,
      _grad(r, const [Color(0xFF0B1033), Color(0xFF2B1B5A), Color(0xFF6C3483)]),
    );
    final rng = Random(7);
    for (var i = 0; i < 70; i++) {
      c.drawCircle(
        Offset(rng.nextDouble() * w, rng.nextDouble() * h),
        w * (.002 + rng.nextDouble() * .004),
        _fill(Colors.white.withValues(alpha: .4 + rng.nextDouble() * .6)),
      );
    }
    final planet = Offset(w * .42, h * .52);
    final pr = w * .2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .03
      ..color = const Color(0xFFFFD6A5).withValues(alpha: .85);
    c.save();
    c.translate(planet.dx, planet.dy);
    c.rotate(-.35);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: pr * 3.2, height: pr * .9),
      ring,
    );
    c.restore();
    c.drawCircle(
      planet,
      pr,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.4, -.4),
          colors: [Color(0xFFFFB86B), Color(0xFFD1495B), Color(0xFF6A1B4D)],
        ).createShader(Rect.fromCircle(center: planet, radius: pr)),
    );
    c.save();
    c.translate(planet.dx, planet.dy);
    c.rotate(-.35);
    c.clipRect(Rect.fromLTWH(-pr * 2, 0, pr * 4, pr * 2));
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: pr * 3.2, height: pr * .9),
      ring,
    );
    c.restore();
    c.drawCircle(
      Offset(w * .82, h * .17),
      w * .075,
      _fill(const Color(0xFFF1F1E6)),
    );
    c.drawCircle(
      Offset(w * .845, h * .15),
      w * .075,
      _fill(const Color(0xFF2B1B5A)),
    );
    final ridge = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * .88)
      ..lineTo(w * .18, h * .8)
      ..lineTo(w * .35, h * .9)
      ..lineTo(w * .6, h * .78)
      ..lineTo(w * .82, h * .9)
      ..lineTo(w, h * .84)
      ..lineTo(w, h)
      ..close();
    c.drawPath(ridge, _fill(const Color(0xFF0B1033)));
  }
}

/// Ve mot o cua tranh: o o hang [row], cot [col] trong luoi [n] x [n].
class ArtTilePainter extends CustomPainter {
  const ArtTilePainter({
    required this.art,
    required this.row,
    required this.col,
    required this.n,
  });

  final int art;
  final int row;
  final int col;
  final int n;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-col * size.width, -row * size.height);
    SlidingArt.paint(canvas, Size(size.width * n, size.height * n), art);
  }

  @override
  bool shouldRepaint(ArtTilePainter old) =>
      old.art != art || old.row != row || old.col != col || old.n != n;
}

/// Ve ca buc tranh (xem truoc / hinh thu nho).
class ArtPainter extends CustomPainter {
  const ArtPainter(this.art);

  final int art;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    SlidingArt.paint(canvas, size, art);
  }

  @override
  bool shouldRepaint(ArtPainter old) => old.art != art;
}
