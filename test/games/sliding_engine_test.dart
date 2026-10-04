import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/sliding/domain/sliding_engine.dart';

SlidingPuzzle _solvedBoard(int n) =>
    SlidingPuzzle([for (var i = 1; i < n * n; i++) i, 0], size: n);

void main() {
  test('sinh de: giai duoc (parity), khong da giai san, moi kich thuoc', () {
    for (final n in [3, 4, 5]) {
      for (var seed = 0; seed < 25; seed++) {
        final g = SlidingPuzzle.generate(size: n, rng: Random(seed));
        expect(g.solved, isFalse);
        expect(SlidingPuzzle.isSolvable(g.tiles, n), isTrue);
        expect(g.tiles.toSet(), {for (var i = 0; i < n * n; i++) i});
      }
    }
  });

  test('isSolvable: bang hoan vi le la khong giai duoc', () {
    final t = _solvedBoard(4).tiles;
    final tmp = t[0];
    t[0] = t[1];
    t[1] = tmp;
    expect(SlidingPuzzle.isSolvable(t, 4), isFalse);
    final t3 = _solvedBoard(3).tiles;
    final x = t3[0];
    t3[0] = t3[1];
    t3[1] = x;
    expect(SlidingPuzzle.isSolvable(t3, 3), isFalse);
  });

  test('cung seed cho cung de (DAILY)', () {
    final a = SlidingPuzzle.generate(rng: Random(42));
    final b = SlidingPuzzle.generate(rng: Random(42));
    expect(a.tiles, b.tiles);
  });

  test('truot ca hang va cot, bam sai thi khong di', () {
    final row = SlidingPuzzle([
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0, 13, 14, 15, //
    ]);
    expect(row.tap(15), isTrue);
    expect(row.tiles.sublist(12), [13, 14, 15, 0]);
    expect(row.moves, 1);
    final col = SlidingPuzzle([
      1, 2, 3, 0, 5, 6, 7, 4, 9, 10, 11, 8, 13, 14, 15, 12, //
    ]);
    expect(col.tap(15), isTrue);
    expect(col.tiles[3], 4);
    expect(col.tiles[15], 0);
    final g = _solvedBoard(4);
    expect(g.tap(0), isFalse);
    expect(g.tap(15), isFalse);
    expect(g.moves, 0);
  });

  test('vuot theo huong dieu khien o ke o trong', () {
    final g = _solvedBoard(3);
    // o trong o (2,2): vuot xuong -> o phia tren (2,1)... tile o (1,2)=6 truot xuong
    expect(g.slide(SlideDir.down), isTrue);
    expect(g.tiles[8], 6);
    expect(g.tiles[5], 0);
    expect(g.slide(SlideDir.right), isTrue);
    expect(g.slide(SlideDir.up), isTrue);
    expect(g.slide(SlideDir.left), isTrue);
    final c = SlidingPuzzle([1, 2, 3, 4, 5, 6, 7, 8, 0], size: 3);
    expect(c.slide(SlideDir.up), isFalse);
    expect(c.slide(SlideDir.left), isFalse);
  });

  test('undo nhieu buoc ve dung trang thai ban dau', () {
    final g = SlidingPuzzle.generate(rng: Random(7));
    final start = List<int>.of(g.tiles);
    final r = Random(1);
    var done = 0;
    while (done < 20) {
      if (g.tap(r.nextInt(16))) done++;
    }
    expect(g.moves, 20);
    for (var i = 0; i < 20; i++) {
      expect(g.undo(), isTrue);
    }
    expect(g.tiles, start);
    expect(g.moves, 0);
    expect(g.canUndo, isFalse);
    expect(g.undo(), isFalse);
  });

  test('undo hoan tac ca nuoc truot chuoi', () {
    final g = SlidingPuzzle([
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0, 13, 14, 15, //
    ]);
    final before = List<int>.of(g.tiles);
    g.tap(15);
    expect(g.undo(), isTrue);
    expect(g.tiles, before);
  });

  test(
    'restore: toJson/fromJson giu bang, luot, lich su; json hong nem loi',
    () {
      final g = SlidingPuzzle.generate(size: 5, rng: Random(3));
      g
        ..tap(g.blank == 0 ? 1 : 0)
        ..slide(SlideDir.left)
        ..slide(SlideDir.up);
      final back = SlidingPuzzle.fromJson(g.toJson());
      expect(back.tiles, g.tiles);
      expect(back.size, 5);
      expect(back.moves, g.moves);
      expect(back.history, g.history);
      while (back.undo()) {}
      expect(back.moves, 0);
      expect(
        () => SlidingPuzzle.fromJson({
          'tiles': [1, 1, 0, 2],
          'size': 2,
          'moves': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => SlidingPuzzle.fromJson({
          'tiles': [1, 2],
          'size': 3,
          'moves': 0,
        }),
        throwsFormatException,
      );
    },
  );

  test('goi y 3x3 la toi uu: lam theo la giai xong va khong vuot qua 31', () {
    for (var seed = 0; seed < 15; seed++) {
      final g = SlidingPuzzle.generate(size: 3, rng: Random(seed));
      final opt = g.solve()!;
      expect(opt.length, lessThanOrEqualTo(31));
      var steps = 0;
      while (!g.solved) {
        final h = g.hint()!;
        expect(g.tap(h), isTrue);
        steps++;
        expect(steps, lessThanOrEqualTo(opt.length));
      }
      expect(steps, opt.length);
    }
  });

  test('goi y 4x4 luon la mot nuoc hop le (khong cho o xa)', () {
    final g = SlidingPuzzle.generate(rng: Random(11));
    for (var i = 0; i < 6; i++) {
      final h = g.hint()!;
      final b = g.blank;
      final adjacent =
          (h - b).abs() == 1 && h ~/ 4 == b ~/ 4 || (h - b).abs() == 4;
      expect(adjacent, isTrue);
      g.tap(h);
    }
    expect(_solvedBoard(4).hint(), isNull);
  });

  test('solve tren bang khong giai duoc tra ve null', () {
    final t = _solvedBoard(3).tiles;
    final x = t[0];
    t[0] = t[1];
    t[1] = x;
    expect(SlidingPuzzle(t, size: 3).solve(), isNull);
  });
}
