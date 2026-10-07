import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
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
                      colors: Candy.blue,
                      icon: Icons.sports_esports_rounded,
                      value: '${tot.played}',
                      label: 'Ván đã chơi',
                    ),
                    _Big(
                      colors: Candy.green,
                      icon: Icons.verified_rounded,
                      value: '${rate.round()}%',
                      label: 'Tỉ lệ thắng',
                    ),
                    _Big(
                      colors: Candy.orange,
                      icon: Icons.local_fire_department_rounded,
                      value: '${store.currentStreak(today)}',
                      label: 'Chuỗi ngày',
                    ),
                    _Big(
                      colors: Candy.purple,
                      icon: Icons.emoji_events_rounded,
                      value: '${store.bestStreak()}',
                      label: 'Chuỗi dài nhất',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: _SectionLabel(
                    'Theo trò chơi',
                    Icons.sports_esports_rounded,
                  ),
                ),
                const SizedBox(height: 14),
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

const _ink = Candy.brown;
const _inkSoft = Color(0xFF9A6B3C);
const _shadow = [Shadow(color: Color(0x88000000), blurRadius: 3)];

/// Nhan muc nho tren nen kem de luon doc duoc.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.icon);

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 16, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Candy.gold, width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Candy.cream, Candy.creamDeep],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            offset: Offset(0, 3),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Candy.brown),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Candy.brown,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({
    required this.icon,
    required this.value,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String value;
  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Candy.gold, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(color: Candy.deep(colors), offset: const Offset(0, 4)),
          const BoxShadow(
            color: Color(0x44000000),
            offset: Offset(0, 8),
            blurRadius: 6,
          ),
        ],
      ),
      child: Stack(
        children: [
          const CandyGloss(radius: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                IconTile(
                  icon: icon,
                  size: 40,
                  background: Colors.white24,
                  foreground: Colors.white,
                ),
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
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            shadows: _shadow,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(
                          color: Colors.white,
                          shadows: _shadow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final t = Theme.of(context).textTheme;
    final colors = Candy.forId(game.id);
    final rate = stats.played == 0
        ? 0.0
        : (stats.won / stats.played).clamp(0.0, 1.0);
    final best = game.bestLabel(stats.best);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CandyFrame(
        padding: 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFFFFF6E3),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Candy.gold, width: 2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: colors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Candy.deep(colors),
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const CandyGloss(),
                      Icon(game.icon, color: Colors.white, size: 24),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              game.title,
                              style: t.titleSmall?.copyWith(
                                color: _ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            '${stats.won}/${stats.played} · ${(rate * 100).round()}%',
                            style: t.labelMedium?.copyWith(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: rate),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 10,
                            color: colors.last,
                            backgroundColor: Candy.creamDeep,
                            semanticsLabel: 'Tỉ lệ thắng ${game.title}',
                          ),
                        ),
                      ),
                      if (best != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          best,
                          style: t.bodySmall?.copyWith(color: _inkSoft),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
