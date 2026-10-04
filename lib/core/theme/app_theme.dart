import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF4F46E5);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: b),
    useMaterial3: true,
    cardTheme: const CardThemeData(elevation: 0),
  );
}
