import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/daily/daily_challenge.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/memory/domain/memory_engine.dart';
import 'package:puzzle_hub/games/memory/presentation/memory_card_view.dart';
import 'package:puzzle_hub/games/memory/presentation/memory_screen.dart';
import 'package:puzzle_hub/games/memory/presentation/memory_symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chi so hai the cung hinh dau tien chua ghep.
(int, int) _pair(MemoryGame g) {
  for (var i = 0; i < g.cards.length; i++) {
    if (g.cards[i].matched) continue;
    final j = g.cards.indexWhere(
      (c) => c.id != i && !c.matched && c.symbol == g.cards[i].symbol,
    );
    return (i, j);
  }
  throw StateError('het cap');
}

void main() {
  group('engine', () {
    test('cac kich thuoc: so the va so cap', () {
      final expected = {
        MemorySize.s3x4: 6,
        MemorySize.s4x4: 8,
        MemorySize.s5x4: 10,
        MemorySize.s6x6: 18,
      };
      for (final e in expected.entries) {
        final g = MemoryGame(size: e.key, rng: Random(1));
        expect(g.cards.length, e.key.cols * e.key.rows);
        expect(g.cards.length, e.value * 2);
        final counts = <int, int>{};
        for (final c in g.cards) {
          counts[c.symbol] = (counts[c.symbol] ?? 0) + 1;
        }
        expect(counts.length, e.value);
        expect(counts.values.every((n) => n == 2), isTrue);
      }
      expect(MemorySize.s4x4.statsId, 'memory.4x4');
      expect(MemorySet.symbolCount, greaterThanOrEqualTo(18));
      expect(memoryIcons.toSet().length, greaterThanOrEqualTo(18));
      expect(MemorySet.values.length, greaterThanOrEqualTo(3));
    });

    test('combo tang khi ghep lien tiep, ve 0 khi sai', () {
      final g = MemoryGame(rng: Random(4));
      final (a, b) = _pair(g);
      expect(g.flip(a), FlipResult.first);
      expect(g.flip(b), FlipResult.match);
      expect(g.combo, 1);
      final (c, d) = _pair(g);
      g
        ..flip(c)
        ..flip(d);
      expect((g.combo, g.bestCombo, g.moves), (2, 2, 2));
      // chon hai the khac hinh
      final x = g.cards.indexWhere((e) => !e.matched);
      final y = g.cards.indexWhere(
        (e) => !e.matched && e.symbol != g.cards[x].symbol,
      );
      g.flip(x);
      expect(g.flip(y), FlipResult.mismatch);
      expect(g.combo, 0);
      expect(g.bestCombo, 2);
      expect(g.waiting, isTrue);
      expect(g.flip(x == 0 ? 1 : 0), FlipResult.ignored);
      g.hideMismatch();
      expect(g.waiting, isFalse);
    });

    test('thang khi ghep het va diem sao', () {
      final g = MemoryGame(size: MemorySize.s3x4, rng: Random(2));
      while (!g.won) {
        final (a, b) = _pair(g);
        g
          ..flip(a)
          ..flip(b);
      }
      expect(g.moves, 6);
      expect(g.stars, 3);
      expect(MemoryGame.starsFor(MemorySize.s4x4, 12, 10), 3);
      expect(MemoryGame.starsFor(MemorySize.s4x4, 18, 10), 2);
      expect(MemoryGame.starsFor(MemorySize.s4x4, 40, 10), 1);
      // qua cham tru mot sao
      expect(MemoryGame.starsFor(MemorySize.s4x4, 12, 8 * 12 + 1), 2);
      expect(MemoryGame.starsFor(MemorySize.s4x4, 40, 9999), 1);
    });

    test('nhin truoc co gioi han', () {
      final g = MemoryGame(rng: Random(1));
      expect(g.usePeek(), isTrue);
      expect(g.usePeek(), isTrue);
      expect(g.usePeek(), isFalse);
      expect(g.peeksLeft, 0);
    });

    test('luu va khoi phuc: kich thuoc, bo hinh, gio, combo', () {
      final g = MemoryGame(
        size: MemorySize.s5x4,
        set: MemorySet.letters,
        rng: Random(7),
      );
      final (a, b) = _pair(g);
      g
        ..flip(a)
        ..flip(b)
        ..seconds = 83
        ..usePeek();
      final r = MemoryGame.fromJson(g.toJson());
      expect(r.size, MemorySize.s5x4);
      expect(r.set, MemorySet.letters);
      expect((r.seconds, r.moves, r.combo, r.peeksUsed), (83, 1, 1, 1));
      expect(r.cards.map((c) => c.symbol), g.cards.map((c) => c.symbol));
      expect(r.cards[a].matched, isTrue);
      expect(
        () => MemoryGame.fromJson({
          'symbols': [1],
          'matched': [true],
        }),
        throwsA(anything),
      );
    });

    test('daily: cung seed cho cung de', () {
      final a = MemoryGame(rng: Random(dailySeed('20261004', 'memory')));
      final b = MemoryGame(rng: Random(dailySeed('20261004', 'memory')));
      expect(a.cards.map((c) => c.symbol), b.cards.map((c) => c.symbol));
    });
  });

  group('widget', () {
    Future<ProviderContainer> pump(WidgetTester t, {String? daily}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(home: MemoryScreen(daily: daily)),
        ),
      );
      await t.pump(const Duration(milliseconds: 1200));
      return c;
    }

    testWidgets('thu thach ngay: choi toi thang, hien sao', (t) async {
      const day = '20261004';
      await pump(t, daily: day);
      expect(find.text('Nhìn trước (2)'), findsOneWidget);
      final model = MemoryGame(rng: Random(dailySeed(day, 'memory')));
      while (!model.won) {
        final (a, b) = _pair(model);
        model
          ..flip(a)
          ..flip(b);
        await t.tap(find.byKey(ValueKey('memory-card-0-$a')));
        await t.pump(const Duration(milliseconds: 350));
        await t.tap(find.byKey(ValueKey('memory-card-0-$b')));
        await t.pump(const Duration(milliseconds: 700));
      }
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Hoàn thành!'), findsOneWidget);
      expect(find.byKey(const ValueKey('memory-star-3')), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('tam dung che ban, nhin truoc tru luot', (t) async {
      await pump(t, daily: '20261004');
      await t.tap(find.byKey(const ValueKey('memory-peek')));
      await t.pump();
      expect(find.text('Nhìn trước (1)'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await t.tap(find.byKey(const ValueKey('memory-pause')));
      await t.pump();
      expect(find.text('Đã tạm dừng'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('memory-resume')));
      await t.pump();
      expect(find.text('Đã tạm dừng'), findsNothing);
    });

    testWidgets('van thuong: sheet chon kich thuoc, bat dau 3x4', (t) async {
      await pump(t);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('memory-size-3x4')), findsOneWidget);
      expect(find.byKey(const ValueKey('memory-set-shapes')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('memory-size-3x4')));
      await t.tap(find.byKey(const ValueKey('memory-set-letters')));
      await t.tap(find.byKey(const ValueKey('memory-start')));
      await t.pumpAndSettle();
      expect(find.byType(MemoryCardView), findsNWidgets(12));
    });

    testWidgets('khoi phuc van dang choi', (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final g = MemoryGame(
        size: MemorySize.s3x4,
        set: MemorySet.shapes,
        rng: Random(1),
      )..seconds = 125;
      await ProgressStore(prefs).saveState('memory', g.toJson());
      final c = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: MemoryScreen()),
        ),
      );
      await t.pump(const Duration(milliseconds: 1500));
      expect(find.byKey(const ValueKey('memory-start')), findsNothing);
      expect(find.text('02:05'), findsOneWidget);
      expect(find.byType(MemoryCardView), findsNWidgets(12));
    });
  });
}
