import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_game.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_solver.dart';

/// Ban co 9x9: o, ghi chu, to sang, vien chon dong, song sang.
class SudokuBoard extends StatelessWidget {
  const SudokuBoard({
    required this.game,
    required this.selected,
    required this.onTap,
    required this.wave,
    required this.waveDelay,
    required this.hintUnit,
    required this.hintCell,
    super.key,
  });

  final SudokuGame game;
  final int? selected;
  final ValueChanged<int> onTap;

  /// Bo dieu khien song sang (0..1) va do tre cua tung o (0..1).
  final Animation<double> wave;
  final Map<int, double> waveDelay;

  /// Don vi va o cua goi y dang hien.
  final List<int> hintUnit;
  final int? hintCell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.maxWidth;
          final cell = size / 9;
          final sel = selected;
          final selVal = sel == null ? 0 : game.values[sel];
          final hintSet = hintUnit.toSet();
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final c = (d.localPosition.dx / cell).floor().clamp(0, 8);
              final r = (d.localPosition.dy / cell).floor().clamp(0, 8);
              onTap(r * 9 + c);
            },
            child: Stack(
              children: [
                // Lop o.
                Column(
                  children: [
                    for (var r = 0; r < 9; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < 9; c++)
                              Expanded(
                                child: _Cell(
                                  key: ValueKey('sudoku-cell-${r * 9 + c}'),
                                  index: r * 9 + c,
                                  game: game,
                                  size: cell,
                                  selVal: selVal,
                                  background: _bg(
                                    scheme,
                                    r * 9 + c,
                                    sel,
                                    selVal,
                                    hintSet,
                                  ),
                                  reduce: reduce,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                // Duong ke.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _GridPainter(scheme)),
                  ),
                ),
                // Song sang.
                if (!reduce)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _WavePainter(wave, waveDelay, scheme.primary),
                      ),
                    ),
                  ),
                // Vien chon dong.
                if (sel != null)
                  AnimatedPositioned(
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    left: sel % 9 * cell,
                    top: sel ~/ 9 * cell,
                    width: cell,
                    height: cell,
                    child: IgnorePointer(
                      child: _PulseBorder(
                        color: game.isWrong(sel)
                            ? scheme.error
                            : scheme.primary,
                        reduce: reduce,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _bg(ColorScheme s, int i, int? sel, int selVal, Set<int> hintSet) {
    if (i == hintCell) return s.tertiaryContainer;
    if (game.isWrong(i)) return s.errorContainer.withValues(alpha: 0.7);
    if (sel != null) {
      if (i == sel) return s.primaryContainer;
      final v = game.values[i];
      if (selVal != 0 && v == selVal) {
        return s.primaryContainer.withValues(alpha: 0.75);
      }
      final same =
          i ~/ 9 == sel ~/ 9 ||
          i % 9 == sel % 9 ||
          SudokuSolver.boxOf(i) == SudokuSolver.boxOf(sel);
      if (same) return s.primary.withValues(alpha: 0.08);
    }
    if (hintSet.contains(i)) return s.tertiaryContainer.withValues(alpha: 0.45);
    return s.surface;
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.index,
    required this.game,
    required this.size,
    required this.selVal,
    required this.background,
    required this.reduce,
    super.key,
  });

  final int index;
  final SudokuGame game;
  final double size;
  final int selVal;
  final Color background;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final v = game.values[index];
    final given = game.isGiven(index);
    Widget child;
    if (v != 0) {
      final color = game.isWrong(index)
          ? s.error
          : given
          ? s.onSurface
          : game.hinted.contains(index)
          ? s.tertiary
          : s.primary;
      final text = Text(
        '$v',
        style: TextStyle(
          fontSize: size * 0.56,
          height: 1,
          fontWeight: given ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      );
      child = given || reduce ? text : PopIn(trigger: '$index-$v', child: text);
    } else if (game.notes[index] != 0) {
      child = _Notes(mask: game.notes[index], size: size, selVal: selVal);
    } else {
      child = const SizedBox.shrink();
    }
    return AnimatedContainer(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 160),
      color: background,
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.mask, required this.size, required this.selVal});

  final int mask;
  final double size;
  final int selVal;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(size * 0.06),
      child: Column(
        children: [
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < 3; c++)
                    Expanded(child: Center(child: _note(s, r * 3 + c + 1))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _note(ColorScheme s, int d) {
    if (mask & (1 << d) == 0) return const SizedBox.shrink();
    final hot = d == selVal;
    return Text(
      '$d',
      style: TextStyle(
        fontSize: size * 0.24,
        height: 1,
        fontWeight: hot ? FontWeight.w800 : FontWeight.w500,
        color: hot ? s.primary : s.onSurfaceVariant,
      ),
    );
  }
}

/// Vien o dang chon, nhip nhe (dung yen khi giam chuyen dong).
class _PulseBorder extends StatefulWidget {
  const _PulseBorder({required this.color, required this.reduce});

  final Color color;
  final bool reduce;

  @override
  State<_PulseBorder> createState() => _PulseBorderState();
}

class _PulseBorderState extends State<_PulseBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduce) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseBorder old) {
    super.didUpdateWidget(old);
    if (widget.reduce && _c.isAnimating) _c.stop();
    if (!widget.reduce && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final t = Curves.easeInOut.transform(_c.value);
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: widget.color, width: 2 + t * 1.2),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.12 + 0.18 * t),
              blurRadius: 3 + 5 * t,
            ),
          ],
        ),
      );
    },
  );
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.s);

  final ColorScheme s;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    final thin = Paint()
      ..color = s.outlineVariant
      ..strokeWidth = 0.6;
    final thick = Paint()
      ..color = s.onSurface.withValues(alpha: 0.75)
      ..strokeWidth = 2;
    for (var k = 1; k < 9; k++) {
      final p = k % 3 == 0 ? thick : thin;
      canvas
        ..drawLine(Offset(k * cell, 0), Offset(k * cell, size.height), p)
        ..drawLine(Offset(0, k * cell), Offset(size.width, k * cell), p);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(4),
      ).deflate(1),
      thick..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.s != s;
}

/// Ve song sang: moi o sang len roi tat theo do tre rieng.
class _WavePainter extends CustomPainter {
  _WavePainter(this.wave, this.delay, this.color) : super(repaint: wave);

  final Animation<double> wave;
  final Map<int, double> delay;
  final Color color;

  /// Phan thoi gian moi o sang (tren thang 0..1 cua ca song).
  static const span = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    final t = wave.value;
    if (t <= 0 || t >= 1 || delay.isEmpty) return;
    final cell = size.width / 9;
    const scale = 1 - span;
    final paint = Paint();
    for (final e in delay.entries) {
      final start = e.value * scale;
      final k = (t - start) / span;
      if (k <= 0 || k >= 1) continue;
      final a = sin(k * pi);
      paint.color = color.withValues(alpha: 0.35 * a);
      final r = Rect.fromLTWH(
        e.key % 9 * cell,
        e.key ~/ 9 * cell,
        cell,
        cell,
      ).deflate(cell * 0.08 * (1 - a));
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cell * 0.18)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.delay != delay;
}
