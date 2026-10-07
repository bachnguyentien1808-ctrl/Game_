import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_solver.dart';

/// Ket qua phat hien: cac hang/cot/khoi (0..8) vua xong va chu so vua du 9.
class SudokuCompletion {
  const SudokuCompletion({
    this.rows = const [],
    this.cols = const [],
    this.boxes = const [],
    this.digit,
  });

  final List<int> rows;
  final List<int> cols;
  final List<int> boxes;

  /// Chu so (1..9) vua du 9 o dung, hoac null.
  final int? digit;

  bool get isEmpty =>
      rows.isEmpty && cols.isEmpty && boxes.isEmpty && digit == null;

  /// Cac o cua moi don vi/chu so vua xong (hop nhat, khong trung).
  Set<int> cells(List<int> values) => {
    for (final r in rows) ...SudokuSolver.units[r],
    for (final c in cols) ...SudokuSolver.units[9 + c],
    for (final b in boxes) ...SudokuSolver.units[18 + b],
    if (digit != null)
      for (var i = 0; i < 81; i++)
        if (values[i] == digit) i,
  };

  /// Diem thuong goc: khoi nhieu hon hang/cot.
  static const rowPoints = 30;
  static const colPoints = 30;
  static const boxPoints = 60;
  static const digitPoints = 40;

  /// Chi giu lai cac hang/cot/khoi/chu so CHUA tung xong trong [awarded]
  /// (va ghi chung vao do), nen moi don vi chi duoc thuong/thong bao mot lan.
  SudokuCompletion takeNew(Set<String> awarded) {
    return SudokuCompletion(
      rows: [
        for (final r in rows)
          if (awarded.add('r$r')) r,
      ],
      cols: [
        for (final c in cols)
          if (awarded.add('c$c')) c,
      ],
      boxes: [
        for (final b in boxes)
          if (awarded.add('b$b')) b,
      ],
      digit: digit != null && awarded.add('d$digit') ? digit : null,
    );
  }

  /// So hang/cot/khoi xong cung luc bang MOT nuoc di.
  int get unitCount => rows.length + cols.length + boxes.length;

  /// He so combo: xong 2 don vi cung luc x1.5, 3 don vi tro len x2.
  double get combo => switch (unitCount) {
    0 || 1 => 1.0,
    2 => 1.5,
    _ => 2.0,
  };

  /// Diem thuong (da nhan [mult] theo do kho va he so [combo], lam tron den
  /// chuc). Mot so an duoc ca hang lan khoi thi duoc diem cao hon.
  int points(double mult) {
    final total =
        rows.length * rowPoints +
        cols.length * colPoints +
        boxes.length * boxPoints +
        (digit != null ? digitPoints : 0);
    return total == 0 ? 0 : max(10, (total * mult * combo / 10).round() * 10);
  }

  /// Cac thong bao ("Hàng 3 và Cột 5 xong!", "Đã đủ số 7!").
  List<String> get messages {
    final parts = [
      for (final r in rows) 'Hàng ${r + 1}',
      for (final c in cols) 'Cột ${c + 1}',
      for (final b in boxes) 'Khối ${b + 1}',
    ];
    final out = <String>[];
    if (parts.isNotEmpty) {
      final text = parts.length == 1
          ? parts.first
          : '${parts.sublist(0, parts.length - 1).join(', ')} và ${parts.last}';
      out.add('$text xong!');
    }
    if (digit != null) out.add('Đã đủ số $digit!');
    return out;
  }
}

bool _full(List<int> values, List<int> unit) {
  var seen = 0;
  for (final j in unit) {
    final v = values[j];
    if (v < 1 || v > 9) return false;
    seen |= 1 << v;
  }
  return seen == 0x3FE; // du 1..9, moi so dung mot lan
}

/// Khoa cac hang/cot/khoi da xong dung (day du, khong o nao sai) cua [values].
/// Nguoi choi khong duoc sua cac o nay nua.
Set<int> lockedCells(List<int> values, bool Function(int) isWrong) {
  bool ok(List<int> unit) => _full(values, unit) && !unit.any(isWrong);
  final out = <int>{};
  for (var u = 0; u < 27; u++) {
    final unit = SudokuSolver.units[u];
    if (ok(unit)) out.addAll(unit);
  }
  return out;
}

/// Khoa cac don vi dang day dung ('r3', 'c5', 'b2') de khong thuong lai.
Set<String> fullUnitKeys(List<int> values) => {
  for (var u = 0; u < 27; u++)
    if (_full(values, SudokuSolver.units[u])) '${'rcb'[u ~/ 9]}${u % 9}',
};

/// Phat hien ket qua cua mot lan dat dung so o o [i] (thuan Dart).
/// [values] la luoi SAU khi dat. Chi xet hang/cot/khoi chua [i] va chu so cua [i].
SudokuCompletion detectCompletion(List<int> values, int i) {
  final v = values[i];
  if (v < 1 || v > 9) return const SudokuCompletion();
  final r = i ~/ 9;
  final c = i % 9;
  final b = SudokuSolver.boxOf(i);
  var digit = false;
  var count = 0;
  var rowsSeen = 0;
  var colsSeen = 0;
  var boxesSeen = 0;
  for (var j = 0; j < 81; j++) {
    if (values[j] != v) continue;
    count++;
    rowsSeen |= 1 << (j ~/ 9);
    colsSeen |= 1 << (j % 9);
    boxesSeen |= 1 << SudokuSolver.boxOf(j);
  }
  if (count == 9 &&
      rowsSeen == 0x1FF &&
      colsSeen == 0x1FF &&
      boxesSeen == 0x1FF) {
    digit = true;
  }
  return SudokuCompletion(
    rows: _full(values, SudokuSolver.units[r]) ? [r] : const [],
    cols: _full(values, SudokuSolver.units[9 + c]) ? [c] : const [],
    boxes: _full(values, SudokuSolver.units[18 + b]) ? [b] : const [],
    digit: digit ? v : null,
  );
}

/// Do tre (0..1) cua tung o theo khoang cach toi o vua dat (song lan toa).
Map<int, double> burstDelays(Set<int> cells, int origin) {
  return {
    for (final j in cells)
      j: max((j ~/ 9 - origin ~/ 9).abs(), (j % 9 - origin % 9).abs()) / 8,
  };
}

/// Vong sang xanh + tia sao tren tung o vua hoan thanh, lan theo do tre.
class SudokuBurstPainter extends CustomPainter {
  SudokuBurstPainter(this.anim, this.delay) : super(repaint: anim);

  final Animation<double> anim;
  final Map<int, double> delay;

  static const _span = 0.5;
  static const _colors = [
    Color(0xFFFFEB3B),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFFF80AB),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final now = anim.value;
    if (now <= 0 || now >= 1 || delay.isEmpty) return;
    final cell = size.width / 9;
    for (final e in delay.entries) {
      final t = (now - e.value * (1 - _span)) / _span;
      if (t <= 0 || t >= 1) continue;
      final c = Offset((e.key % 9 + .5) * cell, (e.key ~/ 9 + .5) * cell);
      final ease = Curves.easeOutCubic.transform(t);
      final fade = (1 - t).clamp(0.0, 1.0);
      canvas.drawCircle(
        c,
        cell * (.3 + .4 * ease),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * fade + 1
          ..color = const Color(0xFF2EC27E).withValues(alpha: fade),
      );
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4 + .3;
        final p = c + Offset(cos(a), sin(a)) * cell * (.3 + .45 * ease);
        final paint = Paint()
          ..color = _colors[i % _colors.length].withValues(alpha: fade);
        final star = Path();
        final k = cell * .08 * (1 - t * .5);
        for (var j = 0; j < 8; j++) {
          final rad = j.isEven ? k * 1.6 : k * .6;
          final b = -pi / 2 + j * pi / 4;
          final pt = p + Offset(cos(b), sin(b)) * rad;
          j == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(star..close(), paint);
      }
    }
  }

  @override
  bool shouldRepaint(SudokuBurstPainter old) => old.delay != delay;
}

/// Bong bong xanh noi len roi mo dan; moi thong bao mot vien.
class SudokuCompletionToast extends StatelessWidget {
  const SudokuCompletionToast({required this.messages, super.key});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (_, k, child) {
        final up = Curves.easeOutCubic.transform((k * 2).clamp(0.0, 1.0));
        final opacity = k < .7 ? 1.0 : (1 - (k - .7) / .3).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 10 - 26 * up),
            child: Transform.scale(
              scale: .6 + .4 * Curves.easeOutBack.transform(up),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white, width: 2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: Candy.green,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        m,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
