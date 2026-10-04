import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_game.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_solver.dart';

const _easy =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const _sol =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

List<int> _g(String s) => [for (final c in s.codeUnits) c - 48];

SudokuGame _game({bool limit = true}) => SudokuGame(
  puzzle: _g(_easy),
  solution: _g(_sol),
  level: SudokuLevel.medium,
  mistakeLimit: limit,
);

void main() {
  // O (0,2) trong, dap an 4.
  const i = 2;

  test('dat so dung, khong dat duoc vao o de', () {
    final g = _game();
    expect(g.place(0, 9).changed, isFalse);
    final r = g.place(i, 4);
    expect(r.changed, isTrue);
    expect(r.wrong, isFalse);
    expect(g.values[i], 4);
    expect(g.mistakes, 0);
  });

  test('dat sai tang loi, 3 loi thi thua; tat gioi han thi khong thua', () {
    final g = _game();
    for (final v in [1, 2, 3]) {
      expect(g.place(i, v).wrong, isTrue);
    }
    expect(g.mistakes, 3);
    expect(g.isLost, isTrue);
    expect(g.place(i, 4).changed, isFalse);

    final g2 = _game(limit: false);
    for (final v in [1, 2, 3, 6]) {
      g2.place(i, v);
    }
    expect(g2.mistakes, 4);
    expect(g2.isLost, isFalse);
    expect(g2.isWrong(i), isTrue);
  });

  test('ghi chu bat/tat, dat so tu xoa ghi chu o va o lien quan', () {
    final g = _game();
    expect(g.toggleNote(i, 4), isTrue);
    expect(g.toggleNote(i, 7), isTrue);
    expect(g.hasNote(i, 4), isTrue);
    // O (0,3) cung hang co ghi chu 4.
    g.toggleNote(3, 4);
    // O (8,0) khong lien quan.
    g.toggleNote(72, 4);
    g.toggleNote(i, 7);
    expect(g.hasNote(i, 7), isFalse);
    g.place(i, 4);
    expect(g.notes[i], 0);
    expect(g.hasNote(3, 4), isFalse);
    expect(g.hasNote(72, 4), isTrue);
    // Khong ghi chu vao o da co so.
    expect(g.toggleNote(i, 1), isFalse);
  });

  test('hoan tac/lam lai nhieu buoc, khoi phuc ca ghi chu lien quan', () {
    final g = _game();
    g.toggleNote(3, 4);
    g.place(i, 4);
    g.place(3, 6);
    expect(g.undo(), 3);
    expect(g.values[3], 0);
    expect(g.undo(), i);
    expect(g.values[i], 0);
    expect(g.hasNote(3, 4), isTrue);
    expect(g.redo(), i);
    expect(g.values[i], 4);
    expect(g.hasNote(3, 4), isFalse);
    expect(g.canRedo, isTrue);
    // Nuoc moi xoa nhanh lam lai.
    g.erase(i);
    expect(g.canRedo, isFalse);
    expect(g.undo(), i);
    expect(g.values[i], 4);
  });

  test('hoan thanh hang tra ve don vi', () {
    final g = _game();
    final sol = _g(_sol);
    // Dien hang 0 tru o cuoi.
    final empties = [
      for (var c = 0; c < 9; c++)
        if (g.values[c] == 0) c,
    ];
    for (final c in empties.take(empties.length - 1)) {
      expect(g.place(c, sol[c]).completed, isEmpty);
    }
    final last = empties.last;
    final r = g.place(last, sol[last]);
    expect(r.completed, contains(SudokuSolver.units[0]));
  });

  test('goi y: sua o sai truoc, sau do suy luan co giai thich, gioi han 3', () {
    final g = _game();
    g.place(i, 9); // sai
    final h1 = g.useHint(null)!;
    expect(h1.index, i);
    expect(h1.value, 4);
    expect(h1.explanation, contains('không đúng'));
    expect(g.values[i], 4);
    expect(g.isLocked(i), isTrue);
    expect(g.mistakes, 1);
    // Hoan tac khong go duoc o goi y.
    g.undo();
    expect(g.values[i], 4);

    final h2 = g.useHint(null)!;
    expect(h2.value, _g(_sol)[h2.index]);
    expect(h2.explanation, isNotEmpty);
    expect(g.hintsLeft, 1);
    g.useHint(null);
    expect(g.hintsLeft, 0);
    expect(g.useHint(null), isNull);
  });

  test('goi y uu tien o dang chon neu co suy luan', () {
    final g = _game();
    final clean = _g(_easy);
    final target = [
      for (var k = 0; k < 81; k++)
        if (clean[k] == 0 && SudokuSolver.stepAt(clean, k) != null) k,
    ].last;
    final h = g.findHint(target)!;
    expect(h.index, target);
    expect(h.value, _g(_sol)[target]);
  });

  test('dien het thi thang; countOf dem so dung', () {
    final g = _game();
    final sol = _g(_sol);
    for (var k = 0; k < 81; k++) {
      if (g.values[k] == 0) g.place(k, sol[k]);
    }
    expect(g.isWon, isTrue);
    expect(g.countOf(5), 9);
    expect(g.canUndo, isFalse);
  });

  test('toJson/fromJson khoi phuc trang thai; JSON hong nem loi', () {
    final g = _game(limit: false)
      ..toggleNote(3, 2)
      ..place(i, 4)
      ..elapsed = 77;
    g.useHint(null);
    final r = SudokuGame.fromJson(g.toJson());
    expect(r.values, g.values);
    expect(r.notes, g.notes);
    expect(r.hinted, g.hinted);
    expect(r.elapsed, 77);
    expect(r.hintsUsed, 1);
    expect(r.mistakeLimit, isFalse);
    expect(r.level, SudokuLevel.medium);
    expect(
      () =>
          SudokuGame.fromJson({'p': '123', 's': _sol, 'v': _sol, 'n': <int>[]}),
      throwsA(anything),
    );
  });

  test('restart dua ve de ban dau', () {
    final g = _game()
      ..place(i, 1)
      ..elapsed = 30;
    g.useHint(null);
    g.restart();
    expect(g.values, _g(_easy));
    expect(g.mistakes, 0);
    expect(g.hintsUsed, 0);
    expect(g.hinted, isEmpty);
    expect(g.canUndo, isFalse);
  });
}
