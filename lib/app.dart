import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_hub/core/router/app_router.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/core/theme/app_theme.dart';
import 'package:puzzle_hub/core/theme/day_phase.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/features/daily/daily_screen.dart';

class PuzzleHubApp extends ConsumerStatefulWidget {
  const PuzzleHubApp({super.key});

  @override
  ConsumerState<PuzzleHubApp> createState() => _PuzzleHubAppState();
}

class _PuzzleHubAppState extends ConsumerState<PuzzleHubApp> {
  late DayPhase _clock = DayPhase.at(ref.read(todayProvider)());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Che do tu dong: moi phut kiem tra lai gio de doi sang / chieu / toi.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final p = DayPhase.at(ref.read(todayProvider)());
      if (mounted && p != _clock) setState(() => _clock = p);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    // Sang -> ban ngay, Toi -> ban dem, Tu dong -> theo gio thuc (sang/chieu/toi).
    final phase = switch (s.themeMode) {
      ThemeMode.light => DayPhase.day,
      ThemeMode.dark => DayPhase.night,
      ThemeMode.system => _clock,
    };
    return MaterialApp.router(
      title: 'Puzzle Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(s.seed, Brightness.light),
      darkTheme: AppTheme.build(s.seed, Brightness.dark),
      themeMode: phase.isDark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 300),
      builder: (context, child) => BackdropPhaseScope(
        phase: phase,
        child: CandyBackground(
          light: !phase.isDark,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
