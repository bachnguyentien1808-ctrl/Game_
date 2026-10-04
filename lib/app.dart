import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/router/app_router.dart';
import 'package:puzzle_hub/core/theme/app_theme.dart';

class PuzzleHubApp extends StatelessWidget {
  const PuzzleHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Puzzle Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
