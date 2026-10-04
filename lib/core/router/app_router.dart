import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/features/home/home_screen.dart';
import 'package:puzzle_hub/games/game_registry.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    for (final g in gameRegistry)
      GoRoute(path: '/play/${g.id}', builder: (ctx, __) => g.builder(ctx)),
  ],
);
