import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/daily/daily_challenge.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/game_logo.dart';
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
    final sound = ref.watch(settingsProvider.select((s) => s.sound));
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
              SliverAppBar(
                pinned: true,
                toolbarHeight: 140,
                leadingWidth: 240,
                leading: const Padding(
                  padding: EdgeInsets.only(left: 12, top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BrandLogo(height: 132),
                  ),
                ),
                actions: [
                  _RoundAction(
                    tooltip: sound ? 'Tắt âm thanh' : 'Bật âm thanh',
                    icon: sound
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    colors: Candy.green,
                    onPressed: () => ref
                        .read(settingsProvider.notifier)
                        .setSound(on: !sound),
                  ),
                  const SizedBox(width: 8),
                  _RoundAction(
                    tooltip: 'Thống kê',
                    icon: Icons.insights_rounded,
                    colors: Candy.blue,
                    onPressed: () => context.go('/stats'),
                  ),
                  const SizedBox(width: 8),
                  _RoundAction(
                    tooltip: 'Cài đặt',
                    icon: Icons.settings_rounded,
                    colors: Candy.purple,
                    onPressed: () => context.go('/settings'),
                  ),
                  const SizedBox(width: 14),
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
                          child: _ScoreBanner(points: store.totalPoints),
                        ),
                        const SizedBox(height: 14),
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
                            mainAxisExtent: 196,
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

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.colors,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: CandyButton(
          onPressed: onPressed,
          colors: colors,
          circle: true,
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }
}

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

/// Tong diem tich luy cua moi game, dem tang dan khi thay doi.
class _ScoreBanner extends StatelessWidget {
  const _ScoreBanner({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('total-score'),
      padding: const EdgeInsets.fromLTRB(10, 8, 18, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Candy.gold, width: 2.5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Candy.cream, Candy.creamDeep],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFFB07A3E), offset: Offset(0, 4)),
          BoxShadow(
            color: Color(0x55000000),
            offset: Offset(0, 8),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Candy.gold, width: 2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFE066), Color(0xFFF08A1C)],
              ),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tổng điểm',
              style: TextStyle(
                color: Candy.brown,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: points),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              Scoring.format(v),
              style: const TextStyle(
                color: Candy.brown,
                fontWeight: FontWeight.w900,
                fontSize: 28,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.stars_rounded, color: Color(0xFFF08A1C)),
        ],
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
    const shadow = [Shadow(color: Color(0x88000000), blurRadius: 3)];
    return Pressable(
      semanticLabel: 'Thử thách hôm nay: ${game?.title ?? gameId}, $statusText',
      borderRadius: 26,
      onTap: () => context.go('/daily'),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Candy.gold, width: 3),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFB74D), Color(0xFFE65100)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0xFF8D3B00), offset: Offset(0, 5)),
            BoxShadow(
              color: Color(0x66000000),
              offset: Offset(0, 10),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          children: [
            const CandyGloss(radius: 22),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Hero(
                    tag: 'daily-icon',
                    child: IconTile(
                      icon: game?.icon ?? Icons.extension_rounded,
                      size: 64,
                      background: Colors.white24,
                      foreground: Colors.white,
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
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            shadows: shadow,
                          ),
                        ),
                        Text(
                          game?.title ?? gameId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            shadows: shadow,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              status == DailyStatus.done
                                  ? Icons.check_circle_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: t.bodyMedium?.copyWith(
                                color: Colors.white,
                                shadows: shadow,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 30,
                          color: streak > 0
                              ? const Color(0xFFFFEB3B)
                              : Colors.white54,
                        ),
                        Text(
                          '$streak',
                          style: t.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'ngày',
                          style: t.labelSmall?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
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

class _ResumeRow extends StatelessWidget {
  const _ResumeRow({required this.games});

  final List<GameInfo> games;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Chơi tiếp', Icons.play_circle_fill_rounded),
        const SizedBox(height: 10),
        SizedBox(
          height: 66,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final g = games[i];
              final colors = Candy.forId(g.id);
              return _Hoverable(
                scale: 1.08,
                child: Pressable(
                  semanticLabel: 'Chơi tiếp ${g.title}',
                  borderRadius: 18,
                  onTap: () => context.go('/play/${g.id}'),
                  child: Ink(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: colors,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Candy.gold, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Candy.deep(colors),
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GameLogo(id: g.id, size: 40),
                        const SizedBox(width: 10),
                        Text(
                          g.title,
                          style: t.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
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

  static const _palette = [
    Candy.blue,
    Candy.green,
    Candy.purple,
    Candy.orange,
    Candy.pink,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          for (final (i, c) in GameCategory.values.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: CandyButton(
                onPressed: () => onChanged(c),
                colors: _palette[i % _palette.length],
                dim: c != value,
                radius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.icon, size: 18),
                    const SizedBox(width: 6),
                    Text(c.label),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The game o luoi man chinh.
/// Re chuot vao thi o phong to hon cac o khac (chi o may co chuot).
class _Hoverable extends StatefulWidget {
  const _Hoverable({required this.child, this.scale = 1.06});

  final Widget child;
  final double scale;

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final off = animationsOff(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover && !off ? widget.scale : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

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
    return _Hoverable(
      child: Stack(
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
                  border: Border.all(color: Colors.white70, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Candy.deep(colors),
                      offset: const Offset(0, 4),
                    ),
                    const BoxShadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 10),
                      blurRadius: 14,
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GameLogo(id: game.id, size: 52),
                        Expanded(
                          child: !resume
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(
                                    left: 6,
                                    right: 26,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                                              style: t.labelSmall?.copyWith(
                                                color: onCard,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(
                        color: Colors.white70,
                        height: 1.25,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelSmall?.copyWith(color: Colors.white70),
                    ),
                    if (store.gamePoints(game.id) > 0)
                      Text(
                        '★ ${Scoring.format(store.gamePoints(game.id))} điểm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelSmall?.copyWith(
                          color: const Color(0xFFFFEB3B),
                          fontWeight: FontWeight.w800,
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
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              tooltip: 'Cách chơi ${game.title}',
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(
                Icons.help_outline_rounded,
                color: Colors.white70,
              ),
              onPressed: () => showHowTo(context, game),
            ),
          ),
        ],
      ),
    );
  }
}
