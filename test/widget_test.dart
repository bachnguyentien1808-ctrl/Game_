import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/features/home/home_screen.dart';

void main() {
  testWidgets('man hinh chinh liet ke Sudoku', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );
    expect(find.text('Sudoku'), findsOneWidget);
  });
}
