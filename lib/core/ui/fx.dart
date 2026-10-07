import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

/// Phan hoi xuc giac dung chung. Bat/tat qua [GameFx.haptics]
/// (man Cai dat ghi vao day).
abstract final class GameFx {
  static final ValueNotifier<bool> haptics = ValueNotifier(true);

  static void tap() {
    if (haptics.value) HapticFeedback.selectionClick();
  }

  static void success() {
    if (haptics.value) HapticFeedback.mediumImpact();
  }

  static void error() {
    if (haptics.value) HapticFeedback.heavyImpact();
  }
}

/// Hieu ung phao giay khi thang: no tu giua ra roi roi xuong, nhieu mau va
/// hinh (chu nhat, tron, sao). Dat len Stack, hien khi [show] = true.
/// Khong chan thao tac (IgnorePointer).
class Confetti extends StatefulWidget {
  const Confetti({required this.show, super.key});

  final bool show;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  final _rng = Random();
  late final List<_Piece> _pieces = List.generate(
    150,
    (i) => _Piece(_rng, burst: i < 70),
  );

  static const _colors = [
    Color(0xFFFF5252),
    Color(0xFFFFC107),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFB388FF),
    Color(0xFFFF80AB),
    Color(0xFFFFAB40),
    Color(0xFF64FFDA),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.show) _c.forward();
  }

  @override
  void didUpdateWidget(Confetti old) {
    super.didUpdateWidget(old);
    if (widget.show && !old.show) _c.forward(from: 0);
    if (!widget.show && old.show) _c.reset();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value, _colors),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece(Random r, {required this.burst})
    : x = r.nextDouble(),
      speed = 0.6 + r.nextDouble() * 0.9,
      drift = (r.nextDouble() - 0.5) * 0.4,
      size = 6 + r.nextDouble() * 8,
      spin = r.nextDouble() * pi * 4,
      color = r.nextInt(8),
      shape = r.nextInt(3),
      angle = -pi * (0.1 + r.nextDouble() * 0.8),
      power = 0.25 + r.nextDouble() * 0.5,
      delay = r.nextDouble() * 0.2;

  final bool burst;
  final double x;
  final double speed;
  final double drift;
  final double size;
  final double spin;
  final int color;
  final int shape;
  final double angle;
  final double power;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.colors);

  final List<_Piece> pieces;
  final double t;
  final List<Color> colors;

  static Path _star(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(cos(a) * rad, sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    for (final p in pieces) {
      final k = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (k <= 0) continue;
      double x;
      double y;
      if (p.burst) {
        // No tu giua man hinh theo goc ngau nhien, giam toc roi roi do trong luc.
        final out = 1 - pow(1 - k, 3).toDouble();
        final reach = p.power * size.shortestSide * 1.6;
        x = size.width / 2 + cos(p.angle) * reach * out;
        y = size.height * 0.42 + sin(p.angle) * reach * out;
        y += k * k * size.height * 0.9;
      } else {
        x = (p.x + p.drift * k) * size.width;
        y = -20 + k * p.speed * (size.height + 40);
      }
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * k);
      final paint = Paint()
        ..color = colors[p.color].withValues(
          alpha: (1 - k * k * k).clamp(0, 1),
        );
      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.6,
            ),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
        default:
          canvas.drawPath(_star(p.size * 0.7), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Hieu ung "nay" (scale + fade) khi widget xuat hien hoac [trigger] doi.
class PopIn extends StatelessWidget {
  const PopIn({
    required this.child,
    this.trigger,
    this.duration = const Duration(milliseconds: 220),
    super.key,
  });

  final Widget child;

  /// Doi gia tri nay de chay lai hieu ung (vd gia tri o).
  final Object? trigger;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0.6, end: 1),
      duration: duration,
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.scale(scale: v, child: child),
      ),
      child: child,
    );
  }
}

/// Lac ngang ngan (bao loi). Goi `shakeKey.currentState?.shake()`.
class Shake extends StatefulWidget {
  const Shake({required this.child, super.key});

  final Widget child;

  @override
  State<Shake> createState() => ShakeState();
}

class ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  void shake() => _c.forward(from: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.translate(
      offset: Offset(sin(_c.value * pi * 6) * 8 * (1 - _c.value), 0),
      child: child,
    ),
    child: widget.child,
  );
}

/// Vo man thang: cup vang + 3 ngoi sao nay lan luot + phao giay, dat len tren
/// man choi.
class WinBanner extends StatelessWidget {
  const WinBanner({
    required this.show,
    required this.title,
    this.subtitle,
    this.onAgain,
    super.key,
  });

  final bool show;
  final String title;
  final String? subtitle;
  final VoidCallback? onAgain;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (show)
          const Positioned.fill(child: ColoredBox(color: Colors.black38)),
        Positioned.fill(child: Confetti(show: show)),
        if (show)
          Positioned.fill(
            child: Center(
              child: PopIn(
                duration: const Duration(milliseconds: 420),
                child: CandyFrame(
                  padding: 10,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _Stars(),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: Color(0xFFF08A1C), blurRadius: 10),
                            ],
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              subtitle!,
                              style: const TextStyle(
                                color: Candy.creamDeep,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (onAgain != null) ...[
                          const SizedBox(height: 16),
                          CandyButton(
                            onPressed: onAgain,
                            colors: Candy.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 12,
                            ),
                            child: const Text(
                              'Chơi lại',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cup vang o giua, hai ngoi sao hai ben va mot ngoi sao tren; nay dan.
class _Stars extends StatelessWidget {
  const _Stars();

  Widget _star(double size, int i, {double lift = 0}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + i * 220),
      curve: Curves.elasticOut,
      builder: (_, k, _) => Transform.translate(
        offset: Offset(0, -lift),
        child: Transform.scale(
          scale: k.clamp(0.0, 1.5),
          child: Transform.rotate(
            angle: (1 - k) * -1.2,
            child: Icon(
              Icons.star_rounded,
              size: size,
              color: const Color(0xFFFFD54F),
              shadows: const [
                Shadow(color: Color(0xFFF08A1C), blurRadius: 10),
                Shadow(color: Color(0x88000000), offset: Offset(0, 3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [_star(44, 0), _star(72, 1, lift: 8), _star(44, 2)],
      ),
    );
  }
}
