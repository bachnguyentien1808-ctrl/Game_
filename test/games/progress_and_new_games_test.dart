import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/game2048/domain/game2048_engine.dart';
import 'package:puzzle_hub/games/memory/domain/memory_engine.dart';
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
}
