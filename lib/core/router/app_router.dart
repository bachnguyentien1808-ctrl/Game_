import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/features/daily/daily_screen.dart';
import 'package:puzzle_hub/features/home/home_screen.dart';
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';
import 'package:puzzle_hub/features/settings/settings_screen.dart';
import 'package:puzzle_hub/features/stats/stats_screen.dart';
import 'package:puzzle_hub/games/game_registry.dart';

/// Chuyen trang nhanh: trang moi mo dan trong 140 ms; trang cu bien mat ngay
/// (khong mo dan ra) de khong bi bong hinh cua game de len man hinh chinh.
/// Tat han khi he thong giam chuyen dong.
CustomTransitionPage<void> fadeSlidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 140),
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
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
    for (final g in gameRegistry)
      _route(
        '/play/${g.id}',
        (c) => GameIntro(gameId: g.id, child: g.builder(c)),
      ),
  ],
);
