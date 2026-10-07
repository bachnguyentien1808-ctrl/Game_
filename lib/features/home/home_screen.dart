import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/daily/daily_challenge.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/features/common/shell_widgets.dart';
import 'package:puzzle_hub/features/daily/daily_screen.dart';
import 'package:puzzle_hub/features/howto/how_to_sheet.dart';
import 'package:puzzle_hub/features/onboarding/onboarding_view.dart';
import 'package:puzzle_hub/games/game_registry.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboarded));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: onboarded
          ? const _HomeBody(key: ValueKey('home'))
          : OnboardingView(
              key: const ValueKey('intro'),
              onDone: () => ref.read(settingsProvider.notifier).setOnboarded(),
            ),
    );
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  const _HomeBody({super.key});

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  GameCategory _filter = GameCategory.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (animationsOff(context)) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Animation<double> _slot(int i) {
    final start = min(i * 0.07, 0.6);
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(start, min(start + 0.4, 1), curve: Curves.easeOutCubic),
    );
  }

  void _setFilter(GameCategory c) {
    if (c == _filter) return;
    setState(() => _filter = c);
    if (!animationsOff(context)) _enter.forward(from: 0.25);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(progressStoreProvider);
    final today = ref.read(todayProvider)();
    return Scaffold(
      body: ValueListenableBuilder<int>(
        valueListenable: store.version,
        builder: (context, _, _) {
          final resume = [
            for (final g in gameRegistry)
              if (store.hasState(g.id)) g,
          ];
          final games = [
            for (final g in gameRegistry)
              if (_filter == GameCategory.all || categoryOf(g.id) == _filter) g,
          ];
          return CustomScrollView(
            slivers: [
              SliverAppBar.medium(
                title: const Text('Puzzle Hub'),
                actions: [
                  IconButton(
                    tooltip: 'Thống kê',
                    icon: const Icon(Icons.insights_outlined),
                    onPressed: () => context.go('/stats'),
                  ),
                  IconButton(
                    tooltip: 'Cài đặt',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.go('/settings'),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              SliverToBoxAdapter(
                child: ContentWidth(
                  maxWidth: 960,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StaggerIn(
                          animation: _slot(0),
                          child: _DailyHero(store: store, today: today),
                        ),
                        if (resume.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          StaggerIn(
                            animation: _slot(1),
                            child: _ResumeRow(games: resume),
                          ),
                        ],
                        const SizedBox(height: 20),
                        StaggerIn(
                          animation: _slot(2),
                          child: _FilterBar(
                            value: _filter,
                            onChanged: _setFilter,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ContentWidth(
                  maxWidth: 960,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            mainAxisExtent: 168,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                      itemCount: games.length,
                      itemBuilder: (context, i) => StaggerIn(
                        key: ValueKey(games[i].id),
                        animation: _slot(i + 3),
                        child: GameCard(game: games[i], store: store),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DailyHero extends StatelessWidget {
  const _DailyHero({required this.store, required this.today});

  final ProgressStore store;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final key = dateKey(today);
    final gameId = dailyGameFor(today);
    final game = gameById(gameId);
    final status = dailyStatus(store, key, gameId);
    final streak = store.currentStreak(today);
    final statusText = switch (status) {
      DailyStatus.done => 'Đã hoàn thành',
      DailyStatus.inProgress => 'Đang chơi dở',
      DailyStatus.notStarted =>
        game?.dailyBuilder == null ? 'Sắp có' : 'Chưa chơi',
    };
    return Pressable(
      semanticLabel: 'Thử thách hôm nay: ${game?.title ?? gameId}, $statusText',
      borderRadius: 24,
      onTap: () => context.go('/daily'),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [s.primary, Color.lerp(s.primary, s.tertiary, 0.6)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Hero(
              tag: 'daily-icon',
              child: IconTile(
                icon: game?.icon ?? Icons.extension_rounded,
                size: 64,
                background: s.onPrimary.withValues(alpha: 0.18),
                foreground: s.onPrimary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thử thách hôm nay',
                    style: t.labelLarge?.copyWith(
                      color: s.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    game?.title ?? gameId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleLarge?.copyWith(
                      color: s.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        status == DailyStatus.done
                            ? Icons.check_circle_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 16,
                        color: s.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: t.bodyMedium?.copyWith(color: s.onPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 30,
                  color: streak > 0
                      ? Colors.orangeAccent
                      : s.onPrimary.withValues(alpha: 0.5),
                ),
                Text(
                  '$streak',
                  style: t.titleMedium?.copyWith(
                    color: s.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('ngày', style: t.labelSmall?.copyWith(color: s.onPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeRow extends StatelessWidget {
  const _ResumeRow({required this.games});

  final List<GameInfo> games;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chơi tiếp', style: t.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final g = games[i];
              return Pressable(
                semanticLabel: 'Chơi tiếp ${g.title}',
                borderRadius: 16,
                onTap: () => context.go('/play/${g.id}'),
                child: Ink(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: s.tertiaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      IconTile(
                        icon: g.icon,
                        size: 40,
                        background: s.tertiary,
                        foreground: s.onTertiary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        g.title,
                        style: t.titleSmall?.copyWith(
                          color: s.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.play_arrow_rounded,
                        color: s.onTertiaryContainer,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final GameCategory value;
  final ValueChanged<GameCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in GameCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(c.icon, size: 18),
                label: Text(c.label),
                selected: c == value,
                showCheckmark: false,
                onSelected: (_) => onChanged(c),
              ),
            ),
        ],
      ),
    );
  }
}

/// The game o luoi man chinh.
class GameCard extends StatelessWidget {
  const GameCard({required this.game, required this.store, super.key});

  final GameInfo game;
  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colors = Candy.forId(game.id);
    const onCard = Colors.white;
    final stats = store.stats(game.id);
    final resume = store.hasState(game.id);
    final best = game.bestLabel(stats.best);
    final line = stats.played == 0 && stats.won == 0
        ? 'Chưa chơi'
        : 'Đã chơi ${stats.played} · Thắng ${stats.won}';
    return Stack(
      children: [
        Positioned.fill(
          child: Pressable(
            semanticLabel: '${game.title}. ${game.subtitle}',
            onTap: () => context.go('/play/${game.id}'),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white38, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Candy.deep(colors),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconTile(
                        icon: game.icon,
                        size: 48,
                        background: Colors.white24,
                        foreground: onCard,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: onCard,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                game.subtitle,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(
                                  color: Colors.white70,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.labelSmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            if (best != null)
                              Text(
                                best,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (resume)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_arrow_rounded,
                                size: 14,
                                color: onCard,
                              ),
                              Text(
                                'Chơi tiếp',
                                style: t.labelSmall?.copyWith(color: onCard),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton(
            tooltip: 'Cách chơi ${game.title}',
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
            onPressed: () => showHowTo(context, game),
          ),
        ),
      ],
    );
  }
}
