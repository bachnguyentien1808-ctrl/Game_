import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/game2048/domain/game2048_engine.dart';
import 'package:puzzle_hub/games/memory/domain/memory_engine.dart';
import 'package:puzzle_hub/games/nonogram/domain/nonogram_engine.dart';

void main() {
  test('2048 gop dung va cong diem', () {
    final b = Board2048([
      [2, 2, 4, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    expect(b.move(Dir.left), isTrue);
    expect(b.cells[0], [4, 4, 0, 0]);
    expect(b.score, 4);
  });

  test('2048 het nuoc di', () {
    final b = Board2048([
      [2, 4, 2, 4],
      [4, 2, 4, 2],
      [2, 4, 2, 4],
      [4, 2, 4, 2],
    ]);
    expect(b.canMove, isFalse);
  });

  test('nonogram goi y va kiem tra loi giai', () {
    expect(clueOf([true, false, true, true]), [1, 2]);
    final p = NonogramPuzzle(nonogramPuzzles[0].rows);
    final grid = [
      for (final r in p.solution) [for (final v in r) v ? 1 : 0],
    ];
    expect(p.isSolved(grid), isTrue);
    grid[0][0] = 1;
    expect(p.isSolved(grid), isFalse);
  });

  test('tim cap: cap dung giu mo, cap sai cho an', () {
    final g = MemoryGame(rng: Random(3));
    final first = g.cards[0];
    final matchIdx = g.cards.indexWhere(
      (c) => c.symbol == first.symbol && c.id != first.id,
    );
    final otherIdx = g.cards.indexWhere((c) => c.symbol != first.symbol);
    g
      ..flip(0)
      ..flip(matchIdx);
    expect(g.cards[0].matched, isTrue);
    g
      ..flip(1)
      ..flip(otherIdx == 1 ? 2 : otherIdx);
    if (!g.cards[1].matched) {
      expect(g.waiting, isTrue);
      g.hideMismatch();
      expect(g.cards[1].faceUp, isFalse);
    }
  });
}
