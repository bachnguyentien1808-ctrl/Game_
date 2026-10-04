import 'dart:math';

import 'package:puzzle_hub/games/lights_out/domain/lights_out_solver.dart';

/// Tat den: bam mot o se dao trang thai o do va 4 o lang gieng.
/// Giu lich su de hoan tac/lam lai, dem luot so voi so luot toi uu (bo giai
/// GF(2)) va so lan goi y da dung.
class LightsOut {
  LightsOut(
    this.cells, {
    this.moves = 0,
    List<List<bool>>? initial,
    int? optimal,
    this.hintsUsed = 0,
    List<int>? history,
    List<int>? redoStack,
  }) : initial = initial ?? [for (final r in cells) List.of(r)],
       optimal = optimal ?? LightsOutSolver.minPresses(initial ?? cells),
       history = history ?? [],
       redoStack = redoStack ?? [];

  /// Sinh de giai duoc bang cach bam ngau nhien tu bang tat het.
  factory LightsOut.generate({int size = 5, Random? rng}) {
    final r = rng ?? Random();
    List<List<bool>> cells;
    do {
      cells = List.generate(size, (_) => List.filled(size, false));
      for (var i = 0; i < size * 2; i++) {
        pressCells(cells, r.nextInt(size), r.nextInt(size));
      }
    } while (cells.every((row) => row.every((v) => !v)));
    return LightsOut(cells);
  }

  factory LightsOut.fromJson(Map<String, dynamic> j) {
    List<List<bool>> grid(Object? o) => [
      for (final r in o! as List) (r as List).cast<bool>().toList(),
    ];
    final cells = grid(j['cells']);
    final n = cells.length;
    if (n == 0 || cells.any((r) => r.length != n)) {
      throw const FormatException('Luoi khong vuong');
    }
    return LightsOut(
      cells,
      moves: j['moves'] as int? ?? 0,
      initial: j['initial'] == null ? null : grid(j['initial']),
      optimal: j['optimal'] as int?,
      hintsUsed: j['hints'] as int? ?? 0,
      history: (j['history'] as List?)?.cast<int>().toList(),
      redoStack: (j['redo'] as List?)?.cast<int>().toList(),
    );
  }

  /// So lan goi y toi da moi van.
  static const maxHints = 3;

  final List<List<bool>> cells;

  /// Bang luc moi bat dau (de choi lai cung de).
  final List<List<bool>> initial;

  /// So luot it nhat de giai tu bang ban dau; null neu bang khong giai duoc.
  final int? optimal;
  int moves;
  int hintsUsed;

  /// Cac luot da bam (chi so r * size + c) va cac luot da hoan tac.
  final List<int> history;
  final List<int> redoStack;

  int get size => cells.length;

  bool get solved => cells.every((r) => r.every((v) => !v));

  bool get canUndo => history.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  int get hintsLeft => max(0, maxHints - hintsUsed);

  Map<String, dynamic> toJson() => {
    'cells': cells,
    'moves': moves,
    'initial': initial,
    'optimal': optimal,
    'hints': hintsUsed,
    'history': history,
    'redo': redoStack,
  };

  /// [count] = false: chi dao den, khong ghi luot/lich su.
  void press(int r, int c, {bool count = true}) {
    pressCells(cells, r, c);
    if (count) {
      moves++;
      history.add(r * size + c);
      redoStack.clear();
    }
  }

  /// Hoan tac luot gan nhat (tra ve o vua hoan tac hoac null).
  int? undo() {
    if (history.isEmpty) return null;
    final i = history.removeLast();
    pressCells(cells, i ~/ size, i % size);
    redoStack.add(i);
    if (moves > 0) moves--;
    return i;
  }

  /// Lam lai luot vua hoan tac.
  int? redo() {
    if (redoStack.isEmpty) return null;
    final i = redoStack.removeLast();
    pressCells(cells, i ~/ size, i % size);
    history.add(i);
    moves++;
    return i;
  }

  /// O nen bam ke tiep (theo loi giai it luot nhat), khong tru luot goi y.
  int? peekHint() {
    if (solved) return null;
    final s = LightsOutSolver.solve(cells);
    return (s == null || s.isEmpty) ? null : s.first;
  }

  /// Dung mot lan goi y; null neu het luot goi y hoac khong co goi y.
  int? useHint() {
    if (hintsLeft == 0) return null;
    final h = peekHint();
    if (h != null) hintsUsed++;
    return h;
  }

  /// Dua ve bang ban dau.
  void reset() {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        cells[r][c] = initial[r][c];
      }
    }
    moves = 0;
    hintsUsed = 0;
    history.clear();
    redoStack.clear();
  }
}
