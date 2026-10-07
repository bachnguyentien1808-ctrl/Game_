import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/features/howto/game_tutorials.dart';
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';
import 'package:puzzle_hub/games/game_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Moi game trong registry deu co huong dan va chu thich', () {
    for (final g in gameRegistry) {
      final t = gameTutorials[g.id];
      expect(t, isNotNull, reason: '${g.id} thieu huong dan');
      expect(t!.steps.length, greaterThanOrEqualTo(3), reason: g.id);
      expect(t.legend, isNotEmpty, reason: g.id);
    }
  });

  testWidgets('Lan dau vao game tu mo huong dan, lan sau thi khong', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Widget app() => ProviderScope(
      overrides: [
        progressStoreProvider.overrideWithValue(ProgressStore(prefs)),
      ],
      child: const MaterialApp(
        home: GameIntro(gameId: 'minesweeper', child: Scaffold()),
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Mở ô'), findsOneWidget);
    expect(find.text('Bước 1/4'), findsOneWidget);

    // Di het cac buoc toi trang chu thich roi bat dau choi.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Chú thích'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu chơi'));
    await tester.pumpAndSettle();
    expect(find.text('Chú thích'), findsNothing);
    expect(ProgressStore(prefs).tutorialSeen('minesweeper'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Bước 1/4'), findsNothing);
  });
}
