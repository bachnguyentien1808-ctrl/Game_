import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/game2048/domain/game2048_engine.dart';
import 'package:puzzle_hub/games/memory/domain/memory_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'ProgressStore: cong diem theo game va tong, resetAll xoa het',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = ProgressStore(await SharedPreferences.getInstance());
      expect(store.totalPoints, 0);
      await store.addPoints('a', 500);
      await store.addPoints('b', 250);
      await store.addPoints('a', 100);
      await store.addPoints('a', 0);
      expect(store.gamePoints('a'), 600);
      expect(store.gamePoints('b'), 250);
      expect(store.totalPoints, 850);
      await store.resetAll();
      expect(store.totalPoints, 0);
      expect(store.gamePoints('a'), 0);
    },
  );

  test('ProgressStore: chuoi thang, thua dat lai chuoi, ti le thang', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore(await SharedPreferences.getInstance());
    for (var i = 0; i < 3; i++) {
      await store.recordStart('m');
      await store.recordWin('m', score: 10, lowerIsBetter: true);
    }
    await store.recordStart('m');
    await store.recordLoss('m');
    await store.recordStart('m');
    await store.recordWin('m', score: 9, lowerIsBetter: true);
    final s = store.stats('m');
    expect((s.played, s.won, s.streak, s.bestStreak), (5, 4, 1, 3));
    expect(s.winRate, 80);
    expect(const GameStats().winRate, isNull);
  });

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
