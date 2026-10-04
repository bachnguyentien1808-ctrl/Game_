import 'dart:collection';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/lights_out/domain/lights_out_engine.dart';
import 'package:puzzle_hub/games/lights_out/domain/lights_out_levels.dart';
import 'package:puzzle_hub/games/lights_out/domain/lights_out_solver.dart';

List<List<bool>> _grid(int n, int bits) => [
  for (var r = 0; r < n; r++)
    [for (var c = 0; c < n; c++) (bits >> (r * n + c)) & 1 == 1],
];

int _bits(List<List<bool>> g) {
  var b = 0;
  for (var r = 0; r < g.length; r++) {
    for (var c = 0; c < g.length; c++) {
      if (g[r][c]) b |= 1 << (r * g.length + c);
    }
  }
  return b;
}

/// BFS tu bang tat het: khoang cach = so luot it nhat cua moi trang thai.
Map<int, int> _bfs(int n) {
  final dist = {0: 0};
  final q = Queue<int>()..add(0);
  while (q.isNotEmpty) {
    final s = q.removeFirst();
    for (var i = 0; i < n * n; i++) {
      final g = _grid(n, s);
      pressCells(g, i ~/ n, i % n);
      final t = _bits(g);
      if (!dist.containsKey(t)) {
        dist[t] = dist[s]! + 1;
        q.add(t);
      }
    }
  }
  return dist;
}

void main() {
  test('de giai duoc; bam hai lan tra lai nguyen trang', () {
    final g = LightsOut.generate(rng: Random(7));
    expect(g.solved, isFalse);
    final before = [for (final r in g.cells) List.of(r)];
    g
      ..press(2, 2)
      ..press(2, 2);
    expect(g.cells, before);
    expect(g.moves, 2);
  });

  test('solver GF(2) toi uu khop BFS: 3x3 va 4x4 moi trang thai', () {
    for (final n in [3, 4]) {
      final dist = _bfs(n);
      expect(dist.length, n == 3 ? 512 : 4096);
      for (var b = 0; b < (1 << (n * n)); b++) {
        final sol = LightsOutSolver.solve(_grid(n, b));
        final d = dist[b];
        if (d == null) {
          expect(sol, isNull, reason: '$n bits=$b phai vo nghiem');
        } else {
          expect(sol!.length, d, reason: '$n bits=$b');
          final g = _grid(n, b);
          for (final i in sol) {
            pressCells(g, i ~/ n, i % n);
          }
          expect(_bits(g), 0);
        }
      }
    }
  });

  test('solver giai duoc ban sinh ngau nhien o moi kich thuoc 2..8', () {
    final rng = Random(11);
    for (var n = 2; n <= 8; n++) {
      for (var k = 0; k < 20; k++) {
        final g = LightsOut.generate(size: n, rng: rng);
        final sol = LightsOutSolver.solve(g.cells)!;
        expect(sol.length, lessThanOrEqualTo(n * 2));
        expect(g.optimal, sol.length);
        final copy = [for (final r in g.cells) List.of(r)];
        for (final i in sol) {
          pressCells(copy, i ~/ n, i % n);
        }
        expect(copy.every((r) => r.every((v) => !v)), isTrue);
      }
    }
  });

  test('36 man tang dan, giai duoc, toi uu <= so lan bam sinh de', () {
    expect(LightsOutLevels.count, greaterThanOrEqualTo(30));
    var prev = 0;
    final sizes = <int>{};
    for (var l = 1; l <= LightsOutLevels.count; l++) {
      final g = LightsOutLevels.build(l);
      expect(g.size, LightsOutLevels.sizeOf(l));
      expect(g.size, greaterThanOrEqualTo(prev));
      prev = g.size;
      sizes.add(g.size);
      expect(g.solved, isFalse);
      expect(g.optimal, isNotNull);
      expect(g.optimal! >= 1, isTrue);
      // De co dinh theo so man.
      expect(LightsOutLevels.build(l).cells, g.cells);
    }
    expect(sizes, {3, 4, 5, 6});
    expect(LightsOutLevels.sizeOf(1), 3);
    expect(LightsOutLevels.sizeOf(LightsOutLevels.count), 6);
  });

  test('sao: 3 neu <= toi uu, 2 neu <= +3, con lai 1', () {
    expect(LightsOutLevels.stars(4, 4), 3);
    expect(LightsOutLevels.stars(2, 4), 3);
    expect(LightsOutLevels.stars(5, 4), 2);
    expect(LightsOutLevels.stars(7, 4), 2);
    expect(LightsOutLevels.stars(8, 4), 1);
  });

  test('hoan tac, lam lai, goi y', () {
    final g = LightsOutLevels.build(10);
    final start = [for (final r in g.cells) List.of(r)];
    g
      ..press(0, 0)
      ..press(1, 1);
    expect(g.moves, 2);
    expect(g.undo(), 1 * g.size + 1);
    expect(g.moves, 1);
    expect(g.redo(), 1 * g.size + 1);
    g.undo();
    g.press(2, 2); // luot moi xoa hang doi lam lai
    expect(g.canRedo, isFalse);
    g.reset();
    expect(g.cells, start);
    expect(g.moves, 0);

    // Lam theo goi y den khi thang, so luot = toi uu.
    var steps = 0;
    while (!g.solved) {
      final h = g.peekHint()!;
      g.press(h ~/ g.size, h % g.size);
      steps++;
    }
    expect(steps, g.optimal);

    final h = LightsOutLevels.build(3);
    for (var i = 0; i < LightsOut.maxHints; i++) {
      expect(h.useHint(), isNotNull);
    }
    expect(h.useHint(), isNull);
    expect(h.hintsLeft, 0);
  });

  test('luu / khoi phuc ban dang choi, ke ca lich su', () {
    final g = LightsOutLevels.build(20)
      ..press(1, 1)
      ..press(2, 3)
      ..undo()
      ..useHint();
    final r = LightsOut.fromJson(g.toJson());
    expect(r.cells, g.cells);
    expect(r.initial, g.initial);
    expect(r.moves, g.moves);
    expect(r.optimal, g.optimal);
    expect(r.hintsUsed, 1);
    expect(r.history, g.history);
    expect(r.redoStack, g.redoStack);
    r.redo();
    expect(r.moves, 2);
    // Ban luu kieu cu (chi cells + moves) van doc duoc.
    final old = LightsOut.fromJson({'cells': _grid(3, 5), 'moves': 4});
    expect(old.moves, 4);
    expect(old.optimal, isNotNull);
    expect(
      () => LightsOut.fromJson({'cells': <List<bool>>[], 'moves': 0}),
      throwsFormatException,
    );
  });
}
