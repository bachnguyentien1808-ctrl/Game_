import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/kakuro/domain/kakuro_engine.dart';
import 'package:puzzle_hub/games/kakuro/presentation/kakuro_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _pump(
  WidgetTester tester,
  Map<String, Object> init, {
  String? daily,
}) async {
  SharedPreferences.setMockInitialValues(init);
  final prefs = await SharedPreferences.getInstance();
  await tester.binding.setSurfaceSize(const Size(400, 860));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(home: KakuroScreen(daily: daily)),
    ),
  );
  await tester.pump();
  return prefs;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
  await tester.binding.setSurfaceSize(null);
}

void main() {
  testWidgets('ván mới: điền số thì lưu ván, có hoàn tác', (tester) async {
    final prefs = await _pump(tester, {});
    expect(find.text('Kakuro'), findsOneWidget);
    expect(prefs.getString('state.kakuro'), isNotNull);
    await tester.tap(find.byKey(const ValueKey('kakuro-num-7')));
    await tester.pump(const Duration(milliseconds: 300));
    final st = jsonDecode(prefs.getString('state.kakuro')!) as Map;
    expect((st['v'] as List).contains(7), isTrue);
    await tester.tap(find.byTooltip('Hoàn tác'));
    await tester.pump(const Duration(milliseconds: 300));
    final st2 = jsonDecode(prefs.getString('state.kakuro')!) as Map;
    expect((st2['v'] as List).contains(7), isFalse);
    await _unmount(tester);
  });

  testWidgets('khôi phục ván còn một ô, gợi ý thì thắng và ghi kỷ lục', (
    tester,
  ) async {
    final p = KakuroPuzzle.generate(n: 5, density: 0.7, rng: Random(9));
    final v = [for (final r in p.solution) ...r];
    final last = v.lastIndexWhere((x) => x != 0);
    v[last] = 0;
    final prefs = await _pump(tester, {
      'state.kakuro': jsonEncode({
        'p': p.toJson(),
        'lv': 0,
        'v': v,
        'm': List.filled(v.length, 0),
        't': 42,
        'h': 3,
      }),
    });
    expect(find.text('00:42'), findsOneWidget);
    await tester.tap(find.byTooltip('Gợi ý'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Hoàn thành!'), findsOneWidget);
    expect(prefs.getString('state.kakuro'), isNull);
    final stats = ProgressStore(prefs);
    expect(stats.stats('kakuro').won, 1);
    expect(stats.stats('kakuro.n5').best, 42);
    await _unmount(tester);
  });

  testWidgets('trạng thái hỏng thì bắt đầu ván mới', (tester) async {
    final prefs = await _pump(tester, {'state.kakuro': '{"p":1}'});
    final st = jsonDecode(prefs.getString('state.kakuro')!) as Map;
    expect(st['lv'], 1);
    await _unmount(tester);
  });

  testWidgets('thử thách ngày: lưu khoá riêng, hai lần vào cùng đề', (
    tester,
  ) async {
    final prefs = await _pump(tester, {}, daily: '20261004');
    final a = prefs.getString('state.daily.kakuro.20261004');
    expect(a, isNotNull);
    expect(find.text('Kakuro - Thử thách ngày'), findsOneWidget);
    await _unmount(tester);
    final prefs2 = await _pump(tester, {}, daily: '20261004');
    final b = prefs2.getString('state.daily.kakuro.20261004');
    expect((jsonDecode(b!) as Map)['p'], (jsonDecode(a!) as Map)['p']);
    await _unmount(tester);
  });
}
