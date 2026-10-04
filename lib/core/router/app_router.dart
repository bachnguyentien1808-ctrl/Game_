import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/features/daily/daily_screen.dart';
import 'package:puzzle_hub/features/home/home_screen.dart';
import 'package:puzzle_hub/features/settings/settings_screen.dart';
import 'package:puzzle_hub/features/stats/stats_screen.dart';
import 'package:puzzle_hub/games/game_registry.dart';

/// Chuyen trang mo dan + truot nhe len (tat khi he thong giam chuyen dong).
CustomTransitionPage<void> fadeSlidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
      final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(a),
          child: child,
        ),
      );
    },
  );
}

GoRoute _route(String path, Widget Function(BuildContext) b) => GoRoute(
  path: path,
  pageBuilder: (ctx, state) => fadeSlidePage(state, b(ctx)),
);

final appRouter = GoRouter(
  routes: [
    _route('/', (_) => const HomeScreen()),
    _route('/settings', (_) => const SettingsScreen()),
    _route('/stats', (_) => const StatsScreen()),
    _route('/daily', (_) => const DailyScreen()),
    _route('/daily/play', (_) => const DailyPlayScreen()),
    for (final g in gameRegistry) _route('/play/${g.id}', g.builder),
  ],
);
