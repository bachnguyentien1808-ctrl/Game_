import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const defaultSeed = Color(0xFF4F46E5);

  static ThemeData get light => build(defaultSeed, Brightness.light);
  static ThemeData get dark => build(defaultSeed, Brightness.dark);

  static ThemeData build(Color seed, Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      cardTheme: const CardThemeData(elevation: 0),
    );
  }
}
