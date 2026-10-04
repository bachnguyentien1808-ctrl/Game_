import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/nonogram/domain/nonogram_engine.dart';
import 'package:puzzle_hub/games/nonogram/domain/nonogram_progress.dart';
import 'package:puzzle_hub/games/nonogram/presentation/nonogram_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

NonogramGame game(int i) =>
    NonogramGame(NonogramPuzzle(nonogramPuzzles[i].rows));

void main() {
  test(
    'kho tranh: du so luong, vuong, chi # va ., khong qua nhieu dong rong',
    () {
      expect(nonogramPuzzles.length, greaterThanOrEqualTo(24));
      final names = <String>{};
      for (final p in nonogramPuzzles) {
        expect(names.add(p.name), isTrue, reason: 'trung ten ${p.name}');
        final n = p.rows.length;
        expect(nonogramPackSizes, contains(n), reason: p.name);
        var empties = 0;
        for (final r in p.rows) {
          expect(r.length, n, reason: '${p.name} khong vuong');
          expect(RegExp(r'^[#.]+$').hasMatch(r), isTrue, reason: p.name);
          if (!r.contains('#')) empties++;
        }
        for (var c = 0; c < n; c++) {
          if (!p.rows.any((r) => r[c] == '#')) empties++;
        }
        expect(
          empties,
          lessThanOrEqualTo(n ~/ 3),
          reason: '${p.name} nhieu hang rong',
        );
      }
      for (final size in nonogramPackSizes) {
        expect(puzzleIndicesOfSize(size).length, greaterThanOrEqualTo(5));
      }
    },
  );

  test('goi y va kiem tra loi giai', () {
    expect(clueOf([true, false, true, true]), [1, 2]);
    final p = NonogramPuzzle(nonogramPuzzles[0].rows);
    final grid = [
      for (final r in p.solution) [for (final v in r) v ? 1 : 0],
    ];
    expect(p.isSolved(grid), isTrue);
    grid[0][0] = 1;
    expect(p.isSolved(grid), isFalse);
  });

  test('net to hang loat va hoan tac/lam lai theo net', () {
    final g = game(0);
    g.beginStroke();
    final target = g.strokeTarget(1, 0, toolFill);
    expect(target, 1);
    for (var c = 0; c < 5; c++) {
      g.paint(1, c, target, toolFill);
    }
    expect(g.endStroke(), isTrue);
    expect(g.grid[1], [1, 1, 1, 1, 1]);
    expect(g.rowDone(1), isTrue);
    expect(g.undo(), isTrue);
    expect(g.isBlank, isTrue);
    expect(g.canRedo, isTrue);
    expect(g.redo(), isTrue);
    expect(g.grid[1], [1, 1, 1, 1, 1]);
    // net moi xoa lich su lam lai
    g.undo();
    g.tapCell(0, 0, toolMark);
    expect(g.canRedo, isFalse);
  });

  test('net xoa chi xoa o cung loai; X khong de len o to', () {
    final g = game(0);
    g.tapCell(0, 1, toolFill);
    g.beginStroke();
    expect(g.paint(0, 1, 2, toolMark), isFalse); // o da to, khong ghi X de len
    g.endStroke();
    expect(g.grid[0][1], 1);
    g.tapCell(0, 1, toolFill); // cham lai -> xoa
    expect(g.grid[0][1], 0);
  });

  test('dem loi khi to o sai va danh dau hang loi', () {
    final g = game(0);
    g.tapCell(0, 0, toolFill); // (0,0) la o trong
    expect(g.mistakes, 1);
    expect(g.isWrongCell(0, 0), isTrue);
    expect(g.rowHasError(0), isTrue);
    expect(g.colHasError(0), isTrue);
    expect(g.rowHasError(1), isFalse);
  });

  test('goi y lo mot o dung, co gioi han va khoa o', () {
    final g = game(0);
    final rng = Random(1);
    for (var i = 0; i < 3; i++) {
      final h = g.hint(rng);
      expect(h, isNotNull);
      final (r, c) = h!;
      expect(g.isLocked(r, c), isTrue);
      expect(g.grid[r][c] == 1, g.puzzle.solution[r][c]);
    }
    expect(g.hintsLeft, 0);
    expect(g.hint(rng), isNull);
  });

  test('giai het thi isSolved, sao theo thoi gian va loi', () {
    final g = game(0);
    for (var r = 0; r < g.size; r++) {
      for (var c = 0; c < g.size; c++) {
        if (g.puzzle.solution[r][c]) g.tapCell(r, c, toolFill);
      }
    }
    expect(g.isSolved, isTrue);
    expect(g.starsFor(10), 3);
    expect(g.starsFor(g.parSeconds + 1), 2);
    g.mistakes = 9;
    expect(g.starsFor(g.parSeconds + 1), 1);
    expect(g.starsFor(1), 2);
  });

  test('tien do: ghi/doc JSON, ky luc, du lieu hong', () {
    final p = NonogramProgress();
    expect(p.recordWin(0, 100, 2), isTrue);
    expect(p.recordWin(0, 120, 3), isFalse);
    expect(p.best[0], (seconds: 100, stars: 3));
    p.saves[1] = LevelSave(
      grid: [for (var i = 0; i < 5; i++) List.filled(5, 0)],
      seconds: 7,
    );
    final back = NonogramProgress.fromJson(
      p.toJson(),
      (i) => nonogramPuzzles[i].rows.length,
    );
    expect(back.isSolved(0), isTrue);
    expect(back.saves[1]!.seconds, 7);
    final bad = NonogramProgress.fromJson({'v': 2, 'saves': 5}, (i) => 5);
    expect(bad.best, isEmpty);
    expect(NonogramProgress.fromJson(null, (i) => 5).saves, isEmpty);
  });

  testWidgets('man chon man hien du goi; mo tranh, keo to mot hang', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: NonogramScreen()),
      ),
    );
    expect(
      find.text('Đã giải 0/${nonogramPuzzles.length} tranh'),
      findsOneWidget,
    );
    expect(find.text('Gói 5x5'), findsOneWidget);
    expect(find.text('Trái tim'), findsOneWidget);

    await tester.tap(find.text('Trái tim'));
    await tester.pump();
    expect(find.text('Trái tim 5x5'), findsOneWidget);

    // keo ngang qua hang thu hai (hang giua man hinh luoi)
    final board = find.byKey(const ValueKey('nono-grid'));
    final tl = tester.getTopLeft(board);
    final size = tester.getSize(board);
    final cell = size.width / 5;
    final gesture = await tester.startGesture(
      tl + Offset(cell * 0.5, cell * 1.5),
    );
    await gesture.moveTo(tl + Offset(cell * 4.5, cell * 1.5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.undo), findsOneWidget);
    final undoBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    expect(undoBtn.onPressed, isNotNull);

    // nut hoan tac xoa net
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();
    final undoAfter = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    expect(undoAfter.onPressed, isNull);
  });
}
