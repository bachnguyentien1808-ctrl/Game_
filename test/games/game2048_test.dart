import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/game2048/domain/game2048_engine.dart';
import 'package:puzzle_hub/games/game2048/presentation/game2048_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('engine', () {
    test('chuyen dong: truot va gop dung dich', () {
      final b = Board2048([
        [0, 2, 0, 2],
        [4, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      final r = b.slide(Dir.left);
      expect(r.changed, isTrue);
      expect(r.gain, 4);
      expect(b.cells[0], [4, 0, 0, 0]);
      final merged = r.moves.where((m) => m.merged).toList();
      expect(merged.length, 1);
      expect(merged.single.toC, 0);
      expect(r.merges.single, (0, 0, 4));
      // o 4 o hang 1 khong di chuyen
      expect(r.moves.any((m) => m.stays && m.value == 4), isTrue);
    });

    test('khong gop kep: [2,2,2,2] -> [4,4,0,0]', () {
      final b = Board2048([
        [2, 2, 2, 2],
        [4, 4, 8, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      b.slide(Dir.left);
      expect(b.cells[0], [4, 4, 0, 0]);
      expect(b.cells[1], [8, 8, 0, 0]);
      expect(b.score, 16);
    });

    test('khong thay doi thi changed = false', () {
      final b = Board2048([
        [2, 4, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]);
      expect(b.slide(Dir.left).changed, isFalse);
    });

    test('huong phai/len/xuong va ban 3x3, 5x5', () {
      final b3 = Board2048([
        [2, 0, 2],
        [0, 0, 0],
        [2, 0, 0],
      ]);
      b3.slide(Dir.down);
      expect(b3.cells[2], [4, 0, 2]);
      final b5 = Board2048.start(size: 5, rng: Random(1));
      expect(b5.size, 5);
      expect(b5.cells.expand((e) => e).where((v) => v > 0).length, 2);
    });

    test('Game2048: sinh o moi, undo, het luot undo', () {
      final rng = Random(3);
      final g = Game2048(
        Board2048([
          [2, 2, 0, 0],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
        ]),
      );
      final out = g.move(Dir.left, rng);
      expect(out, isNotNull);
      expect(out!.spawn, isNotNull);
      expect(g.score, 4);
      expect(g.undo(), isTrue);
      expect(g.score, 0);
      expect(g.board.cells[0], [2, 2, 0, 0]);
      expect(g.undosLeft, 2);
      for (var i = 0; i < 3; i++) {
        g.move(Dir.left, rng);
        g.undo();
      }
      expect(g.undosLeft, 0);
      g.move(Dir.left, rng);
      expect(g.undo(), isFalse);
    });

    test('game over va thang', () {
      final g = Game2048(
        Board2048([
          [2, 4, 2, 4],
          [4, 2, 4, 2],
          [2, 4, 2, 4],
          [4, 2, 4, 2],
        ]),
      );
      expect(g.isOver, isTrue);
      final w = Game2048(
        Board2048([
          [1024, 1024, 0, 0],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
          [0, 0, 0, 0],
        ]),
      );
      final out = w.move(Dir.left, Random(1));
      expect(out!.justWon, isTrue);
      expect(w.won, isTrue);
      w.continued = true;
      expect(w.target, 2048);
      expect(Game2048.targetFor(3), 512);
    });

    test('toJson/fromJson giu undo, nhan sai kich thuoc thi nem loi', () {
      final g = Game2048.start(size: 5, rng: Random(2));
      g.move(Dir.left, Random(1));
      g.move(Dir.up, Random(1));
      final r = Game2048.fromJson(g.toJson());
      expect(r.size, 5);
      expect(r.undoStack.length, g.undoStack.length);
      expect(r.undosLeft, g.undosLeft);
      expect(
        () => Game2048.fromJson({
          'cells': [
            [0, 0],
            [0, 0],
          ],
          'score': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('widget', () {
    Future<ProgressStore> pump(
      WidgetTester tester, {
      Map<String, Object> prefs = const {},
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      final sp = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPrefsProvider.overrideWithValue(sp)],
          child: MaterialApp(home: Game2048Screen(rng: Random(5))),
        ),
      );
      return ProgressStore(sp);
    }

    testWidgets('vuot doi diem, nut hoan tac, hoi khi van moi', (tester) async {
      final store = await pump(tester);
      expect(find.text('2048  4x4'), findsOneWidget);
      expect(find.byKey(const ValueKey('undo')), findsOneWidget);
      var moved = false;
      for (final k in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
      ]) {
        await tester.sendKeyEvent(k);
        await tester.pump(const Duration(milliseconds: 400));
        if (store.loadState('2048')!['undo'] is List &&
            (store.loadState('2048')!['undo'] as List).isNotEmpty) {
          moved = true;
        }
      }
      expect(moved, isTrue);
      // hoan tac
      final before = (store.loadState('2048')!['undo'] as List).length;
      await tester.tap(find.byKey(const ValueKey('undo')));
      await tester.pump(const Duration(milliseconds: 400));
      final after = (store.loadState('2048')!['undo'] as List).length;
      expect(after, before - 1);
    });

    testWidgets('khoi phuc van 5x5 da luu va hien man da dat dich', (
      tester,
    ) async {
      await pump(
        tester,
        prefs: {
          'state.2048': '{"cells":[[512,2,0],[0,0,0],[0,0,0]],"score":10,"won":true,"continued":false}',
        },
      );
      expect(find.text('2048  3x3'), findsOneWidget);
      expect(find.text('Đã đạt 512!'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Đã đạt 512!'), findsNothing);
    });

    testWidgets('van luu da het nuoc di thi bat dau van moi 4x4', (
      tester,
    ) async {
      await pump(
        tester,
        prefs: {'state.2048': '{"cells":[[2,4,2],[4,2,4],[2,4,2]],"score":10}'},
      );
      expect(find.text('2048  4x4'), findsOneWidget);
      expect(find.text('Hết nước đi'), findsNothing);
    });
  });
}
