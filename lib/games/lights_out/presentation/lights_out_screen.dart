import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/games/lights_out/domain/lights_out_engine.dart';
import 'package:puzzle_hub/games/lights_out/domain/lights_out_levels.dart';
import 'package:puzzle_hub/games/lights_out/presentation/lights_out_play.dart';

/// Tat den: man chon (Man choi / Ngau nhien) va van choi. [daily] != null la
/// thu thach ngay (luoi 5x5 co seed).
class LightsOutScreen extends ConsumerStatefulWidget {
  const LightsOutScreen({super.key, this.daily});

  final String? daily;

  @override
  ConsumerState<LightsOutScreen> createState() => _LightsOutScreenState();
}

class _LightsOutScreenState extends ConsumerState<LightsOutScreen> {
  late final GameStore _store = GameStore(
    ref.read(progressStoreProvider),
    daily: widget.daily,
  );
  LightsSession? _session;
  int _tab = 0;
  int _size = 5;

  bool get _inPlay => widget.daily != null || _session != null;

  void _exitPlay() {
    if (widget.daily != null) {
      context.go(_store.homeRoute);
    } else {
      setState(() => _session = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (widget.daily != null) {
      body = LightsOutPlay(
        session: const LightsSession.daily(),
        store: _store,
        onExit: _exitPlay,
      );
    } else if (_session != null) {
      final s = _session!;
      body = LightsOutPlay(
        key: ValueKey(s),
        session: s,
        store: _store,
        onExit: _exitPlay,
        onNextLevel:
            s.mode == LightsMode.level && s.level < LightsOutLevels.count
            ? () => setState(() => _session = LightsSession.level(s.level + 1))
            : null,
      );
    } else {
      body = _menu(context);
    }
    return PopScope(
      canPop: !_inPlay,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitPlay();
      },
      child: body,
    );
  }

  Widget _menu(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Tắt đèn'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.stairs_outlined),
                      label: Text('Màn chơi'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.shuffle),
                      label: Text('Ngẫu nhiên'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (v) => setState(() => _tab = v.first),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _tab == 0 ? _levels(context) : _random(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _levels(BuildContext context) {
    final stars = loadLevelStars(_store);
    final done = stars.where((e) => e > 0).length;
    final total = stars.fold<int>(0, (a, e) => a + e);
    return Column(
      children: [
        Text(
          'Đã qua $done/${LightsOutLevels.count} màn  ·  $total/${LightsOutLevels.count * 3} sao',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.count(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < LightsOutLevels.count; i++)
                _LevelTile(
                  level: i + 1,
                  size: LightsOutLevels.sizeOf(i + 1),
                  stars: stars[i],
                  locked: i > 0 && stars[i - 1] == 0,
                  onTap: () {
                    GameFx.tap();
                    Sfx.play(SfxKind.tap);
                    setState(() => _session = LightsSession.level(i + 1));
                  },
                  onLocked: () {
                    GameFx.error();
                    Sfx.play(SfxKind.error);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _random(BuildContext context) {
    final t = Theme.of(context);
    final s = t.colorScheme;
    final best = _store.stats('$lightsOutId.$_size').best;
    LightsOut? saved;
    try {
      final j = _store.loadState(lightsOutId);
      if (j != null) saved = LightsOut.fromJson(j);
    } on Object {
      saved = null;
    }
    if (saved != null && saved.solved) saved = null;
    return ListView(
      children: [
        Text('Chọn kích thước bàn', style: t.textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: [
            for (final n in const [3, 4, 5, 6])
              ButtonSegment(value: n, label: Text('${n}x$n')),
          ],
          selected: {_size},
          onSelectionChanged: (v) => setState(() => _size = v.first),
        ),
        const SizedBox(height: 12),
        Text(
          best == null ? 'Chưa có kỷ lục' : 'Kỷ lục: $best lượt',
          textAlign: TextAlign.center,
          style: t.textTheme.bodyMedium?.copyWith(color: s.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () =>
              setState(() => _session = LightsSession.random(_size)),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Ván mới'),
        ),
        if (saved != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(
              () => _session = LightsSession.random(saved!.size, resume: true),
            ),
            icon: const Icon(Icons.history),
            label: Text(
              'Tiếp tục ván dở (${saved.size}x${saved.size}, ${saved.moves} lượt)',
            ),
          ),
        ],
      ],
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.size,
    required this.stars,
    required this.locked,
    required this.onTap,
    required this.onLocked,
  });

  final int level;
  final int size;
  final int stars;
  final bool locked;
  final VoidCallback onTap;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final bg = locked
        ? s.surfaceContainerHighest
        : (stars > 0 ? s.tertiaryContainer : s.primaryContainer);
    final fg = locked
        ? s.onSurfaceVariant.withValues(alpha: 0.6)
        : (stars > 0 ? s.onTertiaryContainer : s.onPrimaryContainer);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('lo_level_$level'),
        borderRadius: BorderRadius.circular(12),
        onTap: locked ? onLocked : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              Icon(Icons.lock_outline, size: 20, color: fg)
            else
              Text(
                '$level',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: fg, fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 2),
            Text(
              '${size}x$size',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: fg),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Icon(
                    i < stars ? Icons.star : Icons.star_border,
                    size: 12,
                    color: i < stars ? Colors.amber.shade700 : fg,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
