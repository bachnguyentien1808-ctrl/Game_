import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('man hinh chinh liet ke game va thong ke', (tester) async {
    SharedPreferences.setMockInitialValues({
      'stats.sudoku': '{"played":3,"won":1,"best":null}',
      'state.sudoku': '{}',
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.text('Sudoku'), findsOneWidget);
    expect(find.textContaining('Đã chơi 3'), findsOneWidget);
    expect(find.text('Chơi tiếp'), findsOneWidget);
  });
}
