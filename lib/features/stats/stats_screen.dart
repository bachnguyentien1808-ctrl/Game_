import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/features/common/shell_widgets.dart';
import 'package:puzzle_hub/features/daily/daily_screen.dart';
import 'package:puzzle_hub/games/game_registry.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(progressStoreProvider);
    final today = ref.read(todayProvider)();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Thống kê'),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: store.version,
        builder: (context, _, _) {
          final tot = store.totals(gameRegistry.map((g) => g.id));
          final rate = tot.played == 0 ? 0 : (tot.won * 100 / tot.played);
          return ContentWidth(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.9,
                  children: [
                    _Big(
                      icon: Icons.sports_esports_outlined,
                      value: '${tot.played}',
                      label: 'Ván đã chơi',
                    ),
                    _Big(
                      icon: Icons.verified_outlined,
                      value: '${rate.round()}%',
                      label: 'Tỉ lệ thắng',
                    ),
                    _Big(
                      icon: Icons.local_fire_department_rounded,
                      value: '${store.currentStreak(today)}',
                      label: 'Chuỗi ngày',
                    ),
                    _Big(
                      icon: Icons.emoji_events_outlined,
                      value: '${store.bestStreak()}',
                      label: 'Chuỗi dài nhất',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Theo trò chơi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final g in gameRegistry)
                  _GameRow(game: g, stats: store.stats(g.id)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      color: s.surfaceContainerHigh,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            IconTile(icon: icon, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Text(
                      value,
                      style: t.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.stats});

  final GameInfo game;
  final GameStats stats;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final rate = stats.played == 0
        ? 0.0
        : (stats.won / stats.played).clamp(0.0, 1.0);
    final best = game.bestLabel(stats.best);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconTile(icon: game.icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(game.title, style: t.titleSmall)),
                    Text(
                      '${stats.won}/${stats.played} · ${(rate * 100).round()}%',
                      style: t.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: rate),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: s.surfaceContainerHighest,
                      semanticsLabel: 'Tỉ lệ thắng ${game.title}',
                    ),
                  ),
                ),
                if (best != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    best,
                    style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
