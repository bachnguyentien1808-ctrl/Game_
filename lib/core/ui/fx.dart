import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Hieu ung phao giay khi thang. Dat len Stack, hien khi [show] = true.
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
    duration: const Duration(milliseconds: 2400),
  );
  final _rng = Random();
  late final List<_Piece> _pieces = List.generate(70, (_) => _Piece(_rng));

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
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.secondary,
      Colors.amber,
      Colors.pinkAccent,
    ];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value, colors),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece(Random r)
    : x = r.nextDouble(),
      speed = 0.6 + r.nextDouble() * 0.9,
      drift = (r.nextDouble() - 0.5) * 0.4,
      size = 5 + r.nextDouble() * 7,
      spin = r.nextDouble() * pi * 4,
      color = r.nextInt(5),
      delay = r.nextDouble() * 0.25;

  final double x;
  final double speed;
  final double drift;
  final double size;
  final double spin;
  final int color;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.colors);

  final List<_Piece> pieces;
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    for (final p in pieces) {
      final k = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final x = (p.x + p.drift * k) * size.width;
      final y = -20 + k * p.speed * (size.height + 40);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * k);
      final paint = Paint()
        ..color = colors[p.color].withValues(alpha: (1 - k * k).clamp(0, 1));
      canvas
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        )
        ..restore();
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

/// Vo man thang: chu "Hoan thanh" + phao giay, dat len tren man choi.
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
    final s = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(child: Confetti(show: show)),
        if (show)
          Positioned.fill(
            child: Center(
              child: PopIn(
                child: Card(
                  color: s.primaryContainer,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 48,
                          color: s.onPrimaryContainer,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (subtitle != null) Text(subtitle!),
                        if (onAgain != null) ...[
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: onAgain,
                            child: const Text('Chơi lại'),
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
