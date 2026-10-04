import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/game2048/domain/game2048_engine.dart';
import 'package:puzzle_hub/games/lights_out/domain/lights_out_engine.dart';
import 'package:puzzle_hub/games/memory/domain/memory_engine.dart';
import 'package:puzzle_hub/games/minesweeper/domain/minesweeper_engine.dart';
import 'package:puzzle_hub/games/sliding/domain/sliding_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ProgressStore: thong ke, ky luc, luu va xoa trang thai', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore(await SharedPreferences.getInstance());
    await store.recordStart('x');
    await store.recordWin('x', score: 30, lowerIsBetter: true);
    await store.recordWin('x', score: 20, lowerIsBetter: true);
    await store.recordWin('x', score: 25, lowerIsBetter: true);
    final s = store.stats('x');
    expect((s.played, s.won, s.best), (1, 3, 20));
    await store.saveState('x', {'a': 1});
    expect(store.loadState('x'), {'a': 1});
    await store.resetAll();
    expect(store.hasState('x'), isFalse);
    expect(store.stats('x').played, 0);
  });

  test('2048 va tim cap: toJson/fromJson khop', () {
    final b = Board2048.start(rng: Random(2));
    expect(Board2048.fromJson(b.toJson()).cells, b.cells);
    final m = MemoryGame(rng: Random(2))..flip(0);
    final r = MemoryGame.fromJson(m.toJson());
    expect(r.cards.map((c) => c.symbol), m.cards.map((c) => c.symbol));
  });

  test('Do min: luot dau an toan, flood fill, thang khi mo het o an toan', () {
    final g = Minesweeper()..open(4, 4, rng: Random(5));
    expect(g.lost, isFalse);
    expect(g.cells.expand((r) => r).where((c) => c.mine).length, 10);
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
    final mine = [
      for (var r = 0; r < 9; r++)
        for (var c = 0; c < 9; c++)
          if (g.cells[r][c].mine) (r, c),
    ].first;
    g.toggleFlag(mine.$1, mine.$2);
    g.open(mine.$1, mine.$2);
    expect(g.lost, isFalse);
    g.toggleFlag(mine.$1, mine.$2);
    g.open(mine.$1, mine.$2);
    expect(g.lost, isTrue);
  });

  test('Tat den: de giai duoc; bam hai lan tra lai nguyen trang', () {
    final g = LightsOut.generate(rng: Random(7));
    expect(g.solved, isFalse);
    final before = [for (final r in g.cells) List.of(r)];
    g
      ..press(2, 2)
      ..press(2, 2);
    expect(g.cells, before);
    expect(g.moves, 2);
  });

  test('Xep so: de luon giai duoc tay (parity) va truot ca hang', () {
    final g = SlidingPuzzle.generate(rng: Random(3));
    expect(g.solved, isFalse);
    expect(g.tiles.toSet(), {for (var i = 0; i < 16; i++) i});
    final solved = SlidingPuzzle([
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      0,
      15,
    ]);
    expect(solved.tap(15), isTrue);
    expect(solved.solved, isTrue);
    final row = SlidingPuzzle([
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      0,
      13,
      14,
      15,
    ]);
    expect(row.tap(15), isTrue);
    expect(row.tiles.sublist(12), [13, 14, 15, 0]);
  });
}
