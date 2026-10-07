import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/audio/sfx_player.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('cai dat: doi che do toi, mau, tat rung/am, xoa tien do', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'stats.sudoku': '{"played":1}'});
    final p = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(p)],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            themeMode: ref.watch(settingsProvider).themeMode,
            darkTheme: ThemeData.dark(),
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();
    expect(p.getString('settings.theme'), 'dark');
    final ctx = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(ctx).brightness, Brightness.dark);

    await tester.tap(find.bySemanticsLabel('Màu Cam'));
    await tester.pumpAndSettle();
    expect(p.getInt('settings.seed'), 4);

    await tester.tap(find.text('Rung'));
    await tester.pumpAndSettle();
    expect(GameFx.haptics.value, isFalse);
    expect(p.getBool('settings.haptics'), isFalse);

    await tester.tap(find.text('Âm thanh'));
    await tester.pumpAndSettle();
    expect(SfxEngine.enabled.value, isFalse);

    await tester.scrollUntilVisible(find.text('Xóa toàn bộ tiến độ'), 100);
    await tester.ensureVisible(find.text('Xóa toàn bộ tiến độ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa toàn bộ tiến độ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(p.containsKey('stats.sudoku'), isFalse);
  });

  test('SettingsController doc gia tri da luu', () async {
    SharedPreferences.setMockInitialValues({
      'settings.theme': 'light',
      'settings.seed': 2,
      'settings.haptics': false,
    });
    final p = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(p)],
    );
    addTearDown(c.dispose);
    final s = c.read(settingsProvider);
    expect(s.themeMode, ThemeMode.light);
    expect(s.seedIndex, 2);
    expect(s.haptics, isFalse);
    expect(GameFx.haptics.value, isFalse);
  });
}
