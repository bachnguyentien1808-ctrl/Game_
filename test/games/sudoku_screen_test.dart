import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/daily/daily_challenge.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_game.dart';
import 'package:puzzle_hub/games/sudoku/presentation/sudoku_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _easy =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const _sol =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

List<int> _g(String s) => [for (final c in s.codeUnits) c - 48];

String _saved({String puzzle = _easy}) => jsonEncode(
  SudokuGame(
    puzzle: _g(puzzle),
    solution: _g(_sol),
    level: SudokuLevel.medium,
  ).toJson(),
);

Future<SharedPreferences> _pump(
  WidgetTester tester,
  Map<String, Object> prefs, {
  String? daily,
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(p)],
      child: MaterialApp(home: SudokuScreen(daily: daily)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  return p;
}

Finder _cell(int i) => find.byKey(ValueKey('sudoku-cell-$i'));
Finder _pad(int d) => find.byKey(ValueKey('sudoku-pad-$d'));

String _cellText(WidgetTester tester, int i) {
  final t = find.descendant(of: _cell(i), matching: find.byType(Text));
  return t.evaluate().isEmpty
      ? ''
      : t.evaluate().map((e) => (e.widget as Text).data).join();
}

Future<void> _step(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  testWidgets('chua co van: man chon do kho kem ky luc, chon thi vao van', (
    tester,
  ) async {
    final p = await _pump(tester, {
      'stats.sudoku.easy': '{"played":4,"won":2,"best":125}',
    });
    expect(find.text('Chọn độ khó'), findsOneWidget);
    for (final l in SudokuLevel.values) {
      expect(find.text(l.label), findsOneWidget);
    }
    expect(find.text('Kỷ lục 02:05 · Thắng 2/4'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sudoku-level-easy')));
    await _step(tester);
    expect(_cell(0), findsOneWidget);
    expect(find.text('Lỗi 0/3'), findsOneWidget);
    final ps = ProgressStore(p);
    expect(ps.stats('sudoku.easy').played, 5);
    expect(ps.stats('sudoku').played, 1);
    final st = ps.loadState('sudoku')!;
    expect(st['lv'], 'easy');
  });

  testWidgets('thu thach ngay: vao thang van, de theo seed ngay', (
    tester,
  ) async {
    const day = '20261004';
    final p = await _pump(tester, {}, daily: day);
    expect(find.text('Chọn độ khó'), findsNothing);
    expect(_cell(0), findsOneWidget);
    final st = ProgressStore(p).loadState('daily.sudoku.$day')!;
    final seed = Random(dailySeed(day, 'sudoku')).nextInt(1 << 31);
    final gen = SudokuEngine.generateLevel(dailyLevel, seed: seed);
    expect(st['p'], gen.puzzle.join());
    expect(ProgressStore(p).loadState('sudoku'), isNull);
  });

  testWidgets('dat so, ghi chu, hoan tac, ban phim may tinh, tam dung', (
    tester,
  ) async {
    await _pump(tester, {'state.sudoku': _saved()});
    // O 2 dap an 4.
    await tester.tap(_cell(2));
    await _step(tester);
    await tester.tap(_pad(4));
    await _step(tester);
    expect(_cellText(tester, 2), '4');

    // Ghi chu o 3.
    await tester.tap(_cell(3));
    await tester.tap(find.text('Ghi chú'));
    await _step(tester);
    await tester.tap(_pad(6));
    await tester.tap(_pad(2));
    await _step(tester);
    expect(_cellText(tester, 3), '26');
    await tester.tap(find.text('Hoàn tác'));
    await _step(tester);
    expect(_cellText(tester, 3), '6');

    // Ban phim: tat ghi chu bang N, go 6.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
    await _step(tester);
    expect(_cellText(tester, 3), '6');
    // Mui ten trai ve o 2, Delete khong xoa duoc? O 2 la so nguoi choi -> xoa.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await _step(tester);
    expect(_cellText(tester, 2), '');

    // Tam dung che ban co.
    await tester.tap(find.byTooltip('Tạm dừng'));
    await _step(tester);
    expect(find.text('Tạm dừng'), findsOneWidget);
    expect(_cell(0), findsNothing);
    await tester.tap(find.text('Tiếp tục'));
    await _step(tester);
    expect(_cell(0), findsOneWidget);
  });

  testWidgets('sai 3 lan thi thua, co man ket thuc', (tester) async {
    await _pump(tester, {'state.sudoku': _saved()});
    await tester.tap(_cell(2));
    for (final v in [1, 2, 3]) {
      await tester.tap(_pad(v));
      await _step(tester);
    }
    expect(find.text('Hết lượt sai'), findsOneWidget);
    expect(find.text('Chơi tiếp, bỏ giới hạn'), findsOneWidget);
    await tester.tap(find.text('Chơi tiếp, bỏ giới hạn'));
    await _step(tester);
    expect(find.text('Hết lượt sai'), findsNothing);
    expect(find.text('Lỗi 3'), findsOneWidget);
  });

  testWidgets('goi y hien giai thich va tru luot', (tester) async {
    await _pump(tester, {'state.sudoku': _saved()});
    expect(find.text('3'), findsWidgets);
    await tester.tap(find.text('Gợi ý'));
    await _step(tester);
    expect(find.byIcon(Icons.lightbulb), findsOneWidget);
    // Badge con 2.
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('thang: ghi ky luc theo do kho va man ket qua', (tester) async {
    // Chi con o 2 trong.
    final almost = _sol.replaceRange(2, 3, '0');
    final p = await _pump(tester, {'state.sudoku': _saved(puzzle: almost)});
    await tester.tap(_cell(2));
    await tester.tap(_pad(4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hoàn thành!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Hoàn thành Vừa!'), findsOneWidget);
    expect(find.text('Kỷ lục mới!'), findsOneWidget);
    final ps = ProgressStore(p);
    expect(ps.stats('sudoku').won, 1);
    expect(ps.stats('sudoku.medium').won, 1);
    expect(ps.stats('sudoku.medium').best, isNotNull);
    expect(ps.loadState('sudoku'), isNull);
    await tester.tap(find.byKey(const ValueKey('sudoku-result-next')));
    await _step(tester);
    expect(find.text('Chọn độ khó'), findsOneWidget);
  });

  testWidgets('man hep 360x740 khong tran, ghi chu va goi y van dung', (
    tester,
  ) async {
    await _pump(tester, {'state.sudoku': _saved()}, size: const Size(360, 740));
    await tester.tap(_cell(2));
    await tester.tap(find.text('Ghi chú'));
    await _step(tester);
    await tester.tap(_pad(9));
    await _step(tester);
    expect(_cellText(tester, 2), '9');
    expect(tester.takeException(), isNull);
  });
}
