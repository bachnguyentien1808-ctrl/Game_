import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/app.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/features/daily/daily_screen.dart';
import 'package:puzzle_hub/features/home/home_screen.dart';
import 'package:puzzle_hub/features/howto/how_to_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpHome(WidgetTester tester, Map<String, Object> prefs) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(p),
        todayProvider.overrideWithValue(() => DateTime(2026, 10, 4)),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('man hinh chinh: hero ngay, choi tiep, the game, thong ke', (
    tester,
  ) async {
    await _pumpHome(tester, {
      'settings.onboarded': true,
      'stats.sudoku': '{"played":3,"won":1,"best":null}',
      'state.sudoku': '{}',
    });
    expect(find.text('Puzzle Hub'), findsWidgets);
    expect(find.text('Thử thách hôm nay'), findsOneWidget);
    expect(find.text('Sudoku'), findsWidgets);
    expect(find.text('Đã chơi 3 · Thắng 1'), findsOneWidget);
    // Hang "Choi tiep" + chip tren the.
    expect(find.text('Chơi tiếp'), findsNWidgets(2));
    expect(find.byTooltip('Cài đặt'), findsOneWidget);
    expect(find.byTooltip('Thống kê'), findsOneWidget);
  });

  testWidgets('loc nhom Tri nho chi con Tim cap', (tester) async {
    await _pumpHome(tester, {'settings.onboarded': true});
    expect(find.text('2048'), findsOneWidget);
    await tester.ensureVisible(find.text('Trí nhớ'));
    await tester.tap(find.text('Trí nhớ'));
    await tester.pumpAndSettle();
    expect(find.text('2048'), findsNothing);
    expect(find.text('Tìm cặp'), findsOneWidget);
  });

  testWidgets('dau ? mo bang Cach choi', (tester) async {
    await _pumpHome(tester, {'settings.onboarded': true});
    await tester.tap(find.byTooltip('Cách chơi 2048'));
    await tester.pumpAndSettle();
    expect(find.byType(HowToSheet), findsOneWidget);
    expect(find.text('Cách chơi'), findsOneWidget);
  });

  testWidgets('lan dau hien gioi thieu, xem xong luu co', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(p)],
        child: const PuzzleHubApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng tới Puzzle Hub'), findsOneWidget);
    await tester.tap(find.text('Tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Thử thách mỗi ngày'), findsOneWidget);
    await tester.tap(find.text('Tiếp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu chơi'));
    await tester.pumpAndSettle();
    expect(p.getBool('settings.onboarded'), isTrue);
    expect(find.text('Thử thách hôm nay'), findsOneWidget);
  });
}
