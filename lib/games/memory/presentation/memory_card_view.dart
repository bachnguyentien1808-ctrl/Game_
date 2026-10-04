import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzle_hub/games/memory/domain/memory_engine.dart';
import 'package:puzzle_hub/games/memory/presentation/memory_symbols.dart';

/// The lat 3D: xoay truc Y ~180 do, sang + nay + hat lap lanh khi ghep dung,
/// lac nhe khi sai, vao man theo nhip (stagger) qua [intro].
class MemoryCardView extends StatefulWidget {
  const MemoryCardView({
    required this.set,
    required this.symbol,
    required this.visible,
    required this.matched,
    required this.mismatch,
    required this.intro,
    required this.index,
    required this.total,
    required this.onTap,
    super.key,
  });

  final MemorySet set;
  final int symbol;

  /// Mat truoc dang ngua (dang lat, da ghep hoac dang nhin truoc).
  final bool visible;
  final bool matched;

  /// Dang la mot trong hai the ghep sai (lac roi up lai).
  final bool mismatch;
  final Animation<double> intro;
  final int index;
  final int total;
  final VoidCallback onTap;

  @override
  State<MemoryCardView> createState() => _MemoryCardViewState();
}

class _MemoryCardViewState extends State<MemoryCardView>
    with TickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.visible ? 1 : 0,
  );
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final CurvedAnimation _introCurve;

  bool get _noAnim => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    final begin = widget.total <= 1 ? 0.0 : widget.index / widget.total * 0.6;
    _introCurve = CurvedAnimation(
      parent: widget.intro,
      curve: Interval(begin, begin + 0.4, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(MemoryCardView old) {
    super.didUpdateWidget(old);
    if (widget.visible != old.visible) {
      if (_noAnim) {
        _flip.value = widget.visible ? 1 : 0;
      } else {
        widget.visible ? _flip.forward() : _flip.reverse();
      }
    }
    if (widget.matched && !old.matched && !_noAnim) _bounce.forward(from: 0);
    if (widget.mismatch && !old.mismatch && !_noAnim) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _introCurve.dispose();
    _flip.dispose();
    _bounce.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: widget.onTap,
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.biggest.shortestSide;
          return AnimatedBuilder(
            animation: Listenable.merge([_flip, _bounce, _shake, _introCurve]),
            builder: (context, _) {
              final angle = _flip.value * pi;
              final front = angle > pi / 2;
              final intro = _introCurve.value.clamp(0.0, 1.2);
              final b = sin(pi * _bounce.value);
              // 40% dau dung yen (cho lat xong), roi lac tat dan.
              final sk = ((_shake.value - 0.4) / 0.6).clamp(0.0, 1.0);
              final dx = _shake.isAnimating
                  ? sin(sk * pi * 5) * 6 * (1 - sk)
                  : 0.0;
              final glow = widget.matched ? (0.35 + 0.65 * b) : 0.0;
              return Opacity(
                opacity: intro.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(dx, 0),
                  child: Transform.scale(
                    scale: intro * (1 + 0.14 * b),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0014)
                              ..rotateY(angle),
                            child: front
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.rotationY(pi),
                                    child: _face(s, side, glow),
                                  )
                                : _back(s, side),
                          ),
                        ),
                        if (_bounce.isAnimating)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _SparklePainter(
                                  _bounce.value,
                                  s.tertiary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _back(ColorScheme s, double side) => DecoratedBox(
    decoration: BoxDecoration(
      color: s.primary,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Center(
      child: Icon(
        Icons.help_outline,
        size: side * 0.42,
        color: s.onPrimary.withValues(alpha: 0.7),
      ),
    ),
  );

  Widget _face(ColorScheme s, double side, double glow) => DecoratedBox(
    decoration: BoxDecoration(
      color: widget.matched
          ? Color.lerp(s.tertiaryContainer, s.tertiary, glow * 0.35)
          : s.primaryContainer,
      borderRadius: BorderRadius.circular(10),
      border: widget.matched ? Border.all(color: s.tertiary, width: 2) : null,
      boxShadow: widget.matched
          ? [
              BoxShadow(
                color: s.tertiary.withValues(alpha: 0.5 * glow),
                blurRadius: 14 * glow,
                spreadRadius: 2 * glow,
              ),
            ]
          : null,
    ),
    child: Center(
      child: MemorySymbol(
        set: widget.set,
        symbol: widget.symbol,
        size: side * 0.5,
      ),
    ),
  );
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * (0.45 + 0.45 * t);
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + t * 0.6;
      final p = c + Offset(cos(a), sin(a)) * r;
      final k = size.shortestSide * 0.07 * (1 - t * 0.5);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - k)
          ..lineTo(p.dx + k * 0.3, p.dy - k * 0.3)
          ..lineTo(p.dx + k, p.dy)
          ..lineTo(p.dx + k * 0.3, p.dy + k * 0.3)
          ..lineTo(p.dx, p.dy + k)
          ..lineTo(p.dx - k * 0.3, p.dy + k * 0.3)
          ..lineTo(p.dx - k, p.dy)
          ..lineTo(p.dx - k * 0.3, p.dy - k * 0.3)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}
