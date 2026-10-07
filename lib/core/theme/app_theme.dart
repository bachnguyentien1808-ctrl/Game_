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
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        // Tieu de trang tren nen anh: chu trang dam co bong, doc ro moi buoi.
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Color(0x99000000), blurRadius: 4)],
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: const CardThemeData(elevation: 0),
    );
  }
}
