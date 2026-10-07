import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/sliding/presentation/sliding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs([Map<String, Object> init = const {}]) {
  SharedPreferences.setMockInitialValues(init);
  return SharedPreferences.getInstance();
}

Future<void> _open(
  WidgetTester tester,
  SharedPreferences prefs, {
  String? daily,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(home: SlidingScreen(daily: daily)),
    ),
  );
}

Map<String, Object> _saved(List<int> tiles, int size, {int moves = 4}) => {
  'state.sliding': jsonEncode({
    'tiles': tiles,
    'size': size,
    'moves': moves,
    'history': <int>[],
    'ms': 5000,
    'hints': 3,
  }),
};

void main() {
  testWidgets('van moi: xao tron co animation roi choi duoc, dem luot', (
    tester,
  ) async {
    await _open(tester, await _prefs());
    expect(find.text('Xếp số 4x4'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    final rect = tester.getRect(find.byType(AspectRatio).first);
    final cell = rect.width / 4;
    for (var i = 0; i < 16; i++) {
      await tester.tapAt(
        rect.topLeft + Offset((i % 4 + .5) * cell, (i ~/ 4 + .5) * cell),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    // Chi con '0' cua o tong diem tren AppBar, khong o so nao hien so 0.
    expect(
      find.descendant(
        of: find.byKey(const Key('score-chip')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Lượt'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('thang: hien WinBanner voi luot, gio, ky luc', (tester) async {
    final prefs = await _prefs(_saved([1, 2, 3, 4, 5, 6, 7, 0, 8], 3));
    await _open(tester, prefs);
    await tester.pump();
    expect(find.text('Xếp số 3x3'), findsOneWidget);
    await tester.tap(find.text('8'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Hoàn thành!'), findsOneWidget);
    expect(find.textContaining('5 lượt'), findsWidgets);
    expect(find.textContaining('Kỷ lục mới'), findsOneWidget);
    expect(
      ProgressStore(prefs).stats('sliding.3').best,
      5,
      reason: 'ky luc theo kich thuoc',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hoan tac va tam dung', (tester) async {
    final prefs = await _prefs(_saved([1, 2, 3, 4, 5, 6, 7, 0, 8], 3));
    await _open(tester, prefs);
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('5'), findsWidgets);
    await tester.tap(find.byTooltip('Hoàn tác'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Tạm dừng'));
    await tester.pump();
    expect(find.text('Tạm dừng'), findsOneWidget);
    await tester.tap(find.text('Chạm để tiếp tục'));
    await tester.pump();
    expect(find.text('Chạm để tiếp tục'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('goi y: tru so lan va chi mot o', (tester) async {
    final prefs = await _prefs(_saved([1, 2, 3, 4, 5, 6, 0, 7, 8], 3));
    await _open(tester, prefs);
    await tester.pump();
    await tester.tap(find.byTooltip('Gợi ý'));
    await tester.pump();
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('2')),
      findsOneWidget,
    ); // huy hieu con 2 lan
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tuy chon: doi sang che do Anh va kich thuoc 3x3', (
    tester,
  ) async {
    await _open(tester, await _prefs());
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Tuỳ chọn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Hiện số trên ô'), findsOneWidget);
    await tester.tap(find.text('3x3'));
    await tester.pumpAndSettle();
    expect(find.text('Xếp số 3x3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Ghép lại bức tranh'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('thu thach ngay: cung de, an chon kich thuoc', (tester) async {
    final prefs = await _prefs();
    await _open(tester, prefs, daily: '20261004');
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Hôm nay'), findsOneWidget);
    await tester.tap(find.byTooltip('Tuỳ chọn'));
    await tester.pumpAndSettle();
    expect(find.text('Kích thước'), findsNothing);
    expect(find.text('Chế độ'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
