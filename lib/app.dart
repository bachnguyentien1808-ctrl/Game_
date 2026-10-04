import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_hub/core/router/app_router.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/core/theme/app_theme.dart';

class PuzzleHubApp extends ConsumerWidget {
  const PuzzleHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'Puzzle Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(s.seed, Brightness.light),
      darkTheme: AppTheme.build(s.seed, Brightness.dark),
      themeMode: s.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 300),
      routerConfig: appRouter,
    );
  }
}
