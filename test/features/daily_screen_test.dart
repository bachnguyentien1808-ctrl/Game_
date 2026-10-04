import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/daily/daily_challenge.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/features/daily/daily_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _today = DateTime(2026, 10, 4);

Future<SharedPreferences> _pump(
  WidgetTester tester,
  Map<String, Object> prefs,
) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(p),
        todayProvider.overrideWithValue(() => _today),
      ],
      child: const MaterialApp(home: DailyScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  return p;
}

void main() {
  testWidgets('chua choi: hien ngay, game cua ngay, chuoi tu hom qua', (
    tester,
  ) async {
    await _pump(tester, {'daily.done': '{"20261003":10,"20261002":null}'});
    expect(find.text(dayLabel(_today)), findsOneWidget);
    final g = gameById(dailyGameFor(_today));
    if (g != null) expect(find.text(g.title), findsOneWidget);
    expect(find.text('2 ngày'), findsNWidgets(2));
    expect(find.text('Tháng 10/2026'), findsOneWidget);
    expect(find.text('Hoàn thành 2/31 ngày'), findsOneWidget);
  });

  testWidgets('da xong hom nay: hien diem, danh dau da mung, don van cu', (
    tester,
  ) async {
    final key = dateKey(_today);
    final p = await _pump(tester, {
      'daily.done': '{"$key":120,"20261003":5}',
      'state.daily.sudoku.20261001': '{}',
    });
    expect(find.textContaining('Đã hoàn thành'), findsOneWidget);
    expect(p.getString('daily.celebrated'), key);
    expect(p.containsKey('state.daily.sudoku.20261001'), isFalse);
    expect(find.text('2 ngày'), findsNWidgets(2));
  });

  testWidgets('doi thang bang mui ten', (tester) async {
    await _pump(tester, {});
    expect(find.byTooltip('Tháng sau'), findsOneWidget);
    await tester.tap(find.byTooltip('Tháng trước'));
    await tester.pump();
    expect(find.text('Tháng 9/2026'), findsOneWidget);
  });
}
