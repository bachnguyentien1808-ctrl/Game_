import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/daily/daily_challenge.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/features/common/shell_widgets.dart';
import 'package:puzzle_hub/games/game_registry.dart';

/// Dong ho cho man ngay; test ghi de de co ngay co dinh.
final todayProvider = Provider<DateTime Function()>((_) => DateTime.now);

GameInfo? gameById(String id) {
  for (final g in gameRegistry) {
    if (g.id == id) return g;
  }
  return null;
}

const _weekdayLong = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];
const _weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String dayLabel(DateTime d) =>
    '${_weekdayLong[d.weekday - 1]}, ${d.day}/${d.month}/${d.year}';

/// Trang thai thu thach cua mot ngay.
enum DailyStatus { notStarted, inProgress, done }

DailyStatus dailyStatus(ProgressStore store, String key, String gameId) {
  if (store.isDailyDone(key)) return DailyStatus.done;
  if (store.hasState('daily.$gameId.$key')) return DailyStatus.inProgress;
  return DailyStatus.notStarted;
}

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});

  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen>
    with SingleTickerProviderStateMixin {
  late final ProgressStore _store = ref.read(progressStoreProvider);
  late final DateTime _today = ref.read(todayProvider)();
  late final String _key = dateKey(_today);
  late DateTime _month = DateTime(_today.year, _today.month);
  late final AnimationController _flame = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _celebrate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _store.pruneDaily(keep: _key);
      if (!mounted) return;
      // Vua hoan thanh hom nay ma chua mung: chay ngon lua + phao giay.
      if (_store.isDailyDone(_key) && _store.lastCelebratedDaily != _key) {
        await _store.markDailyCelebrated(_key);
        if (!mounted) return;
        setState(() => _celebrate = true);
        Sfx.play(SfxKind.win);
        GameFx.success();
        if (!animationsOff(context)) _flame.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _flame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameId = dailyGameFor(_today);
    final game = gameById(gameId);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Thử thách mỗi ngày'),
      ),
      body: Stack(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: _store.version,
            builder: (context, _, _) {
              final done = _store.dailyDone();
              final status = dailyStatus(_store, _key, gameId);
              return ContentWidth(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _TodayCard(
                      today: _today,
                      game: game,
                      gameId: gameId,
                      status: status,
                      score: done[_key],
                    ),
                    const SizedBox(height: 16),
                    _StreakRow(
                      current: _store.currentStreak(_today),
                      best: _store.bestStreak(),
                      flame: _flame,
                    ),
                    const SizedBox(height: 16),
                    _WeekStrip(today: _today, done: done),
                    const SizedBox(height: 16),
                    _MonthCalendar(
                      month: _month,
                      today: _today,
                      done: done,
                      onMonth: (m) => setState(() => _month = m),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned.fill(child: Confetti(show: _celebrate)),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.today,
    required this.game,
    required this.gameId,
    required this.status,
    required this.score,
  });

  final DateTime today;
  final GameInfo? game;
  final String gameId;
  final DailyStatus status;
  final int? score;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final available = game?.dailyBuilder != null;
    final (statusIcon, statusText) = switch (status) {
      DailyStatus.done => (
        Icons.check_circle_rounded,
        score == null ? 'Đã hoàn thành' : 'Đã hoàn thành · $score điểm',
      ),
      DailyStatus.inProgress => (Icons.timelapse_rounded, 'Đang chơi dở'),
      DailyStatus.notStarted => (Icons.radio_button_unchecked, 'Chưa chơi'),
    };
    return Card(
      color: s.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dayLabel(today),
              style: t.labelLarge?.copyWith(color: s.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Hero(
                  tag: 'daily-icon',
                  child: IconTile(
                    icon: game?.icon ?? Icons.extension_rounded,
                    size: 80,
                    background: s.primary,
                    foreground: s.onPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Câu đố hôm nay',
                        style: t.labelMedium?.copyWith(
                          color: s.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        game?.title ?? gameId,
                        style: t.headlineSmall?.copyWith(
                          color: s.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Row(
                          key: ValueKey(status),
                          children: [
                            Icon(
                              statusIcon,
                              size: 18,
                              color: s.onPrimaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                available ? statusText : 'Sắp có',
                                style: t.bodyMedium?.copyWith(
                                  color: s.onPrimaryContainer,
                                ),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: available
                    ? () {
                        GameFx.tap();
                        Sfx.play(SfxKind.tap);
                        context.go('/daily/play');
                      }
                    : null,
                icon: Icon(
                  status == DailyStatus.done
                      ? Icons.replay_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(switch ((available, status)) {
                  (false, _) => 'Sắp có',
                  (_, DailyStatus.done) => 'Xem lại',
                  (_, DailyStatus.inProgress) => 'Chơi tiếp',
                  _ => 'Chơi ngay',
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  const _StreakRow({
    required this.current,
    required this.best,
    required this.flame,
  });

  final int current;
  final int best;
  final Animation<double> flame;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Chuỗi hiện tại',
            value: '$current ngày',
            icon: AnimatedBuilder(
              animation: flame,
              builder: (_, child) {
                final v = flame.value;
                // Bung to roi lang lai, chop sang khi vua hoan thanh.
                final scale =
                    1 + 0.6 * Curves.elasticOut.transform(v) * (1 - v);
                return Transform.scale(scale: scale, child: child);
              },
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 32,
                color: current > 0 ? Colors.deepOrange : s.outline,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Dài nhất',
            value: '$best ngày',
            icon: Icon(
              Icons.emoji_events_rounded,
              size: 32,
              color: best > 0 ? Colors.amber.shade700 : s.outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      color: s.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    label,
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

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.today, required this.done});

  final DateTime today;
  final Map<String, int?> done;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    return Card(
      color: s.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            for (final d in days)
              Expanded(
                child: Semantics(
                  label:
                      '${dayLabel(d)}: ${done.containsKey(dateKey(d)) ? 'đã xong' : 'chưa xong'}',
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        Text(
                          _weekdayShort[d.weekday - 1],
                          style: t.labelSmall?.copyWith(
                            color: s.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _DayDot(
                          day: d.day,
                          done: done.containsKey(dateKey(d)),
                          today: dateKey(d) == dateKey(today),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.done, required this.today});

  final int day;
  final bool done;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? s.primary : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: today ? s.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: done
          ? Icon(Icons.check_rounded, size: 18, color: s.onPrimary)
          : Text(
              '$day',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: today ? s.primary : s.onSurface,
                fontWeight: today ? FontWeight.w700 : null,
              ),
            ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.today,
    required this.done,
    required this.onMonth,
  });

  final DateTime month;
  final DateTime today;
  final Map<String, int?> done;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final first = DateTime(month.year, month.month);
    final daysIn = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final count = done.keys.where((k) {
      final d = parseDateKey(k);
      return d.year == month.year && d.month == month.month;
    }).length;
    final isCurrent = month.year == today.year && month.month == today.month;
    return Card(
      color: s.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Tháng trước',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () =>
                      onMonth(DateTime(month.year, month.month - 1)),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Tháng ${month.month}/${month.year}',
                        style: t.titleMedium,
                      ),
                      Text(
                        'Hoàn thành $count/$daysIn ngày',
                        style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tháng sau',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isCurrent
                      ? null
                      : () => onMonth(DateTime(month.year, month.month + 1)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final w in _weekdayShort)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: t.labelSmall?.copyWith(
                          color: s.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.15,
              children: [
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysIn; day++)
                  Center(
                    child: _DayDot(
                      day: day,
                      done: done.containsKey(
                        dateKey(DateTime(month.year, month.month, day)),
                      ),
                      today: isCurrent && day == today.day,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// /daily/play: dung man game cua ngay o che do thu thach.
class DailyPlayScreen extends ConsumerWidget {
  const DailyPlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.read(todayProvider)();
    final game = gameById(dailyGameFor(today));
    final builder = game?.dailyBuilder;
    if (builder != null) return builder(dateKey(today));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/daily'),
        ),
        title: const Text('Thử thách mỗi ngày'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon: game?.icon ?? Icons.hourglass_empty, size: 96),
            const SizedBox(height: 16),
            Text('Sắp có', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${game?.title ?? 'Trò chơi này'} chưa hỗ trợ thử thách ngày.',
            ),
          ],
        ),
      ),
    );
  }
}
