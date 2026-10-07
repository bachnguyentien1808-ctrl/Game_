import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/minesweeper/domain/minesweeper_engine.dart';

List<(int, int)> _minesOf(Minesweeper g) => [
  for (var r = 0; r < g.rows; r++)
    for (var c = 0; c < g.cols; c++)
      if (g.cells[r][c].mine) (r, c),
];

void main() {
  test('Do min: luot dau an toan, flood fill, thang khi mo het o an toan', () {
    final g = Minesweeper()..open(4, 4, rng: Random(5));
    expect(g.lost, isFalse);
    expect(_minesOf(g).length, 10);
    expect(g.cells[4][4].open, isTrue);
    for (final row in g.cells) {
      for (final c in row) {
        if (!c.mine) c.open = true;
      }
    }
    expect(g.won, isTrue);
    final back = Minesweeper.fromJson(g.toJson());
    expect(back.cells[4][4].near, g.cells[4][4].near);
  });

  test('Do min: mo trung min la thua, co khong mo duoc', () {
    final g = Minesweeper()..open(0, 0, rng: Random(1));
    final mine = _minesOf(g).first;
    g
      ..toggleFlag(mine.$1, mine.$2)
      ..open(mine.$1, mine.$2);
    expect(g.lost, isFalse);
    g
      ..toggleFlag(mine.$1, mine.$2)
      ..open(mine.$1, mine.$2);
    expect(g.lost, isTrue);
    expect(g.boom, mine);
  });

  test('Muc do kho: kich thuoc va so min', () {
    expect(
      [for (final l in MineLevel.values.take(3)) (l.rows, l.cols, l.mines)],
      [(9, 9, 10), (16, 16, 40), (16, 30, 99)],
    );
    expect(MineLevel.medium.statsId, 'minesweeper.medium');
    expect(MineLevel.byKey('zzz'), MineLevel.easy);
    final g = Minesweeper(rows: 16, cols: 30, mines: 99)
      ..open(8, 15, rng: Random(2));
    expect(_minesOf(g).length, 99);
    expect(g.cells.length * g.cells.first.length, 480);
  });

  test('Tuy chinh: kiem tra hop le', () {
    expect(Minesweeper.validateConfig(10, 12, 20), isNull);
    expect(Minesweeper.validateConfig(4, 10, 5), isNotNull);
    expect(Minesweeper.validateConfig(10, 41, 5), isNotNull);
    expect(Minesweeper.validateConfig(10, 10, 0), isNotNull);
    expect(Minesweeper.validateConfig(5, 5, 17), isNotNull);
    expect(Minesweeper.validateConfig(5, 5, 16), isNull);
    expect(() => Minesweeper.custom(5, 5, 99), throwsArgumentError);
    expect(Minesweeper.custom(6, 7, 8).mines, 8);
    // Ban day mine toi da van mo duoc luot dau an toan.
    final g = Minesweeper.custom(5, 5, 16)..open(2, 2, rng: Random(3));
    expect(g.lost, isFalse);
    expect(_minesOf(g).length, 16);
  });

  test('Chord: du co thi mo cac o ke, thieu co thi khong lam gi', () {
    final g = Minesweeper()..open(4, 4, rng: Random(7));
    // Tim o so da mo co ke mine va ke o chua mo.
    (int, int)? target;
    for (var r = 0; r < 9 && target == null; r++) {
      for (var c = 0; c < 9; c++) {
        final cell = g.cells[r][c];
        if (cell.open && cell.near > 0) {
          target = (r, c);
          break;
        }
      }
    }
    final t = target!;
    expect(g.chord(t.$1, t.$2), isEmpty); // chua co co nao
    // Cam co dung moi mine ke ben.
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final r = t.$1 + dr;
        final c = t.$2 + dc;
        if (r < 0 || c < 0 || r > 8 || c > 8) continue;
        if (g.cells[r][c].mine) g.toggleFlag(r, c);
      }
    }
    final opened = g.chord(t.$1, t.$2);
    expect(g.lost, isFalse);
    for (final p in opened) {
      expect(g.cells[p.$1][p.$2].open, isTrue);
      expect(g.cells[p.$1][p.$2].mine, isFalse);
    }
  });

  test('Chord voi co sai cho thi no min', () {
    final g = Minesweeper()..open(4, 4, rng: Random(7));
    (int, int)? t;
    for (var r = 0; r < 9 && t == null; r++) {
      for (var c = 0; c < 9; c++) {
        final cell = g.cells[r][c];
        if (cell.open && cell.near == 1) {
          t = (r, c);
          break;
        }
      }
    }
    final p = t!;
    // Cam 1 co vao o an toan, de mine that o ke van chua mo.
    (int, int)? wrong;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final r = p.$1 + dr;
        final c = p.$2 + dc;
        if (r < 0 || c < 0 || r > 8 || c > 8) continue;
        final cell = g.cells[r][c];
        if (!cell.open && !cell.mine) wrong = (r, c);
      }
    }
    if (wrong == null) return; // khong co o an toan chua mo ke ben
    g
      ..toggleFlag(wrong.$1, wrong.$2)
      ..chord(p.$1, p.$2);
    expect(g.lost, isTrue);
  });

  test('Daily: cung seed cho cung ban, o khoi dau da mo', () {
    final a = Minesweeper.daily(rng: Random(12345));
    final b = Minesweeper.daily(rng: Random(12345));
    final c = Minesweeper.daily(rng: Random(999));
    expect(a.toJson(), b.toJson());
    expect(a.toJson(), isNot(c.toJson()));
    expect((a.rows, a.cols, a.mines), (16, 16, 40));
    expect(_minesOf(a).length, 40);
    expect(a.placed, isTrue);
    expect(
      a.cells.expand((r) => r).where((x) => x.open).length,
      greaterThan(0),
    );
    expect(a.lost, isFalse);
    // Khong o mo nao la mine.
    expect(a.cells.expand((r) => r).any((x) => x.open && x.mine), isFalse);
  });

  test('Luu/khoi phuc giu nguyen ban', () {
    final g = Minesweeper(rows: 16, cols: 30, mines: 99)
      ..open(3, 3, rng: Random(4))
      ..toggleFlag(15, 29);
    final back = Minesweeper.fromJson(g.toJson());
    expect((back.rows, back.cols, back.mines), (16, 30, 99));
    expect(back.toJson(), g.toJson());
    expect(back.flagsLeft, g.flagsLeft);
  });

  test('flagAllMines cam du moi mine', () {
    final g = Minesweeper()..open(4, 4, rng: Random(5));
    for (final row in g.cells) {
      for (final c in row) {
        if (!c.mine) c.open = true;
      }
    }
    g.flagAllMines();
    expect(g.flagsLeft, 0);
  });

  test('Goi y: luon la o an toan that, null truoc luot dau', () {
    expect(Minesweeper().safeHint(), isNull);
    var found = 0;
    for (var seed = 0; seed < 40; seed++) {
      final g = Minesweeper(rows: 16, cols: 16, mines: 40)
        ..open(8, 8, rng: Random(seed));
      final h = g.safeHint();
      if (h == null) continue;
      found++;
      expect(g.cells[h.$1][h.$2].mine, isFalse, reason: 'seed $seed');
      expect(g.cells[h.$1][h.$2].open, isFalse);
    }
    expect(found, greaterThan(0));
  });

  test('Khong doan mo: ban sinh ra giai duoc bang suy luan tu o dau', () {
    for (var seed = 0; seed < 30; seed++) {
      final g = Minesweeper()..open(4, 4, rng: Random(seed));
      expect(g.isLogicSolvable(4, 4), isTrue, reason: 'seed $seed');
      expect(g.lost, isFalse);
    }
  });

  test('Khong doan mo: ban Kho van sinh nhanh va hop le', () {
    final sw = Stopwatch()..start();
    final g = Minesweeper(rows: 16, cols: 30, mines: 99)
      ..open(8, 15, rng: Random(3));
    expect(sw.elapsed.inSeconds, lessThan(5));
    expect(_minesOf(g).length, 99);
    expect(g.lost, isFalse);
  });

  test('Tat noGuess: van dat dung so mine, tranh o dau', () {
    final g = Minesweeper(noGuess: false)..open(4, 4, rng: Random(2));
    expect(_minesOf(g).length, 10);
    expect(g.cells[4][4].mine, isFalse);
  });
}
