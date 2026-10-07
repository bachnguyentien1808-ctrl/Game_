import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/minesweeper/presentation/minesweeper_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ban 9x9 chi co mot mine o (0,0), chua mo o nao.
String _oneMineState() {
  final bits = [
    for (var r = 0; r < 9; r++)
      [for (var c = 0; c < 9; c++) (r == 0 && c == 0) ? 1 : 0],
  ];
  return jsonEncode({
    'mines': 1,
    'placed': true,
    'lost': false,
    'bits': bits,
    'seconds': 7,
    'moved': true,
    'hints': 0,
    'level': 'easy',
  });
}

Future<SharedPreferences> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  String? daily,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(sp)],
      child: MaterialApp(home: MinesweeperScreen(daily: daily)),
    ),
  );
  return sp;
}

Future<void> _end(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('Khoi phuc van dang choi (ca gio) va thang khi mo het', (
    tester,
  ) async {
    final sp = await _pump(
      tester,
      prefs: {'state.minesweeper': _oneMineState()},
    );
    expect(find.textContaining('Dễ · 9x9 · 1 mìn'), findsOneWidget);
    expect(find.text('7 s'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cell-8-8')));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Dò mìn - Thắng!'), findsOneWidget);
    expect(find.text('Chơi lại'), findsOneWidget);
    expect(sp.getString('stats.minesweeper.easy'), contains('"won":1'));
    expect(sp.getString('stats.minesweeper'), contains('"best":7'));
    expect(sp.containsKey('state.minesweeper'), isFalse);
    // 7 giay tren ban De: nhanh nen duoc diem toi da (1000), cong vao tong.
    expect(sp.getInt('score.total'), 1000);
    expect(sp.getInt('score.game.minesweeper'), 1000);
    expect(find.textContaining('điểm'), findsWidgets);
    await _end(tester);
  });

  testWidgets('Mo trung mine: thua, mat khong doi', (tester) async {
    await _pump(tester, prefs: {'state.minesweeper': _oneMineState()});
    await tester.tap(find.byKey(const Key('cell-0-0')));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Dò mìn - Nổ mìn'), findsOneWidget);
    expect(find.byIcon(Icons.sentiment_very_dissatisfied), findsOneWidget);
    await _end(tester);
  });

  testWidgets('Cam co bang nhan giu, bo dem co giam', (tester) async {
    await _pump(tester, prefs: {'state.minesweeper': _oneMineState()});
    expect(find.text('1'), findsWidgets);
    await tester.longPress(find.byKey(const Key('cell-3-3')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.flag), findsWidgets);
    expect(find.text('0'), findsWidgets);
    await _end(tester);
  });

  testWidgets('Chon do kho Kho qua sheet, ban 16x30', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('level')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('level-hard')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Khó · 16x30 · 99 mìn'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('Che do ngay: ban 16x16 co o mo san, khong co nut do kho', (
    tester,
  ) async {
    await _pump(tester, daily: '20261004');
    expect(
      find.textContaining('Thử thách ngày · 16x16 · 40 mìn'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('level')), findsNothing);
    await _end(tester);
  });
}
