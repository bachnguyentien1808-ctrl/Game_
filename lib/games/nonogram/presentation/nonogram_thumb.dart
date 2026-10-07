import 'package:flutter/material.dart';

/// Hinh thu nho cua mot tranh: tranh mau da giai, hoac luoi dang to do.
class NonogramThumb extends StatelessWidget {
  const NonogramThumb({
    required this.solution,
    required this.top,
    required this.bottom,
    this.grid,
    this.colored = false,
    super.key,
  });

  final List<List<bool>> solution;
  final Color top;
  final Color bottom;

  /// Luoi dang choi (1 = o to) khi chua giai.
  final List<List<int>>? grid;

  /// true: ve tranh mau day du (da giai).
  final bool colored;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ThumbPainter(
        solution: solution,
        grid: grid,
        colored: colored,
        top: top,
        bottom: bottom,
        empty: const Color(0xFF2B4F68),
        fill: const Color(0xFFB07CFF),
        line: const Color(0xFF173B52),
      ),
      size: Size.infinite,
    );
  }
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter({
    required this.solution,
    required this.grid,
    required this.colored,
    required this.top,
    required this.bottom,
    required this.empty,
    required this.fill,
    required this.line,
  });

  final List<List<bool>> solution;
  final List<List<int>>? grid;
  final bool colored;
  final Color top;
  final Color bottom;
  final Color empty;
  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final n = solution.length;
    final cell = size.shortestSide / n;
    final p = Paint();
    for (var r = 0; r < n; r++) {
      final rowColor = Color.lerp(top, bottom, n == 1 ? 0 : r / (n - 1))!;
      for (var c = 0; c < n; c++) {
        final rect = Rect.fromLTWH(
          c * cell,
          r * cell,
          cell,
          cell,
        ).deflate(colored ? 0 : 0.4);
        if (colored) {
          p.color = solution[r][c] ? rowColor : Colors.transparent;
        } else if (grid != null && grid![r][c] == 1) {
          p.color = fill;
        } else {
          p.color = empty;
        }
        canvas.drawRect(rect, p);
      }
    }
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => true;
}
