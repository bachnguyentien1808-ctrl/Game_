import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_hub/core/audio/sfx_player.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/fx.dart';

/// Bang mau chu dao chon trong Cai dat (seed cua ColorScheme).
const seedColors = <(String, Color)>[
  ('Chàm', Color(0xFF4F46E5)),
  ('Lam', Color(0xFF0284C7)),
  ('Ngọc', Color(0xFF0D9488)),
  ('Lục', Color(0xFF16A34A)),
  ('Cam', Color(0xFFEA580C)),
  ('Hồng', Color(0xFFDB2777)),
];

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.seedIndex = 0,
    this.haptics = true,
    this.sound = true,
    this.onboarded = false,
  });

  final ThemeMode themeMode;
  final int seedIndex;
  final bool haptics;
  final bool sound;

  /// Da xem gioi thieu lan dau.
  final bool onboarded;

  Color get seed => seedColors[seedIndex.clamp(0, seedColors.length - 1)].$2;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? seedIndex,
    bool? haptics,
    bool? sound,
    bool? onboarded,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    seedIndex: seedIndex ?? this.seedIndex,
    haptics: haptics ?? this.haptics,
    sound: sound ?? this.sound,
    onboarded: onboarded ?? this.onboarded,
  );
}

/// Doc/ghi cai dat qua SharedPreferences, ap dung ngay vao GameFx/SfxEngine.
class SettingsController extends Notifier<AppSettings> {
  static const _kTheme = 'settings.theme';
  static const _kSeed = 'settings.seed';
  static const _kHaptics = 'settings.haptics';
  static const _kSound = 'settings.sound';
  static const _kOnboarded = 'settings.onboarded';

  @override
  AppSettings build() {
    final p = ref.watch(sharedPrefsProvider);
    final themeName = p.getString(_kTheme);
    final s = AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      seedIndex: (p.getInt(_kSeed) ?? 0).clamp(0, seedColors.length - 1),
      haptics: p.getBool(_kHaptics) ?? true,
      sound: p.getBool(_kSound) ?? true,
      onboarded: p.getBool(_kOnboarded) ?? false,
    );
    _apply(s);
    return s;
  }

  static void _apply(AppSettings s) {
    GameFx.haptics.value = s.haptics;
    SfxEngine.enabled.value = s.sound;
  }

  void _set(AppSettings s) {
    state = s;
    _apply(s);
  }

  Future<void> setThemeMode(ThemeMode m) {
    _set(state.copyWith(themeMode: m));
    return ref.read(sharedPrefsProvider).setString(_kTheme, m.name);
  }

  Future<void> setSeed(int i) {
    _set(state.copyWith(seedIndex: i));
    return ref.read(sharedPrefsProvider).setInt(_kSeed, i);
  }

  Future<void> setHaptics({required bool on}) {
    _set(state.copyWith(haptics: on));
    return ref.read(sharedPrefsProvider).setBool(_kHaptics, on);
  }

  Future<void> setSound({required bool on}) {
    _set(state.copyWith(sound: on));
    return ref.read(sharedPrefsProvider).setBool(_kSound, on);
  }

  Future<void> setOnboarded() {
    _set(state.copyWith(onboarded: true));
    return ref.read(sharedPrefsProvider).setBool(_kOnboarded, true);
  }

  Future<void> resetOnboarding() {
    _set(state.copyWith(onboarded: false));
    return ref.read(sharedPrefsProvider).setBool(_kOnboarded, false);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
