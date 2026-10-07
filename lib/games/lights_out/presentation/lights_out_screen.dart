import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/core/ui/glass.dart';
import 'package:puzzle_hub/core/ui/score_chip.dart';
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';
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
    return CandyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          actions: const [
            ScoreChip(),
            HelpAction(gameId: 'lights_out'),
          ],
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
                  GlassPanel(
                    child: Row(
                      children: [
                        _tabButton(0, Icons.stairs_outlined, 'Màn chơi'),
                        const SizedBox(width: 10),
                        _tabButton(1, Icons.shuffle, 'Ngẫu nhiên'),
                      ],
                    ),
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
      ),
    );
  }

  Widget _tabButton(int value, IconData icon, String label) {
    return Expanded(
      child: CandyButton(
        onPressed: () => setState(() => _tab = value),
        colors: value == 0 ? Candy.orange : Candy.blue,
        dim: _tab != value,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Text(label),
          ],
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
        GlassBar(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: GlassStat(
                  icon: Icons.star,
                  colors: Candy.orange,
                  text:
                      'Đã qua $done/${LightsOutLevels.count} màn  ·  $total/${LightsOutLevels.count * 3} sao',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.count(
            crossAxisCount: 5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            padding: const EdgeInsets.only(bottom: 8),
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
        GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              const Center(child: CandyRibbon(text: 'Chọn kích thước bàn')),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final n in const [3, 4, 5, 6]) ...[
                    if (n != 3) const SizedBox(width: 8),
                    Expanded(
                      child: CandyButton(
                        onPressed: () => setState(() => _size = n),
                        colors: _sizeColors(n),
                        dim: _size != n,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('${n}x$n'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: GlassStat(
                  icon: Icons.emoji_events_outlined,
                  colors: Candy.orange,
                  text: best == null ? 'Chưa có kỷ lục' : 'Kỷ lục: $best lượt',
                ),
              ),
              const SizedBox(height: 22),
              CandyButton(
                onPressed: () =>
                    setState(() => _session = LightsSession.random(_size)),
                colors: Candy.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow),
                    SizedBox(width: 6),
                    Text('Ván mới', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
              if (saved != null) ...[
                const SizedBox(height: 14),
                CandyButton(
                  onPressed: () => setState(
                    () => _session = LightsSession.random(
                      saved!.size,
                      resume: true,
                    ),
                  ),
                  colors: Candy.orange,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Tiếp tục ván dở (${saved.size}x${saved.size}, ${saved.moves} lượt)',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Mau theo kich thuoc bang.
List<Color> _sizeColors(int size) => switch (size) {
  3 => Candy.teal,
  4 => Candy.green,
  5 => Candy.orange,
  6 => Candy.pink,
  _ => Candy.purple,
};

class _LevelTile extends StatefulWidget {
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
  State<_LevelTile> createState() => _LevelTileState();
}

class _LevelTileState extends State<_LevelTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final locked = widget.locked;
    final colors = locked
        ? const [Color(0xFF9AA7B4), Color(0xFF5E6B78)]
        : _sizeColors(widget.size);
    const shadow = [Shadow(color: Color(0x88000000), blurRadius: 2)];
    return GestureDetector(
      key: ValueKey('lo_level_${widget.level}'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: locked ? widget.onLocked : widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.93 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.stars > 0
                  ? const Color(0xFFFFE066)
                  : GlassStyle.of(context).outerBorder,
              width: 2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: Candy.deep(colors),
                offset: Offset(0, _down ? 1 : 4),
              ),
              const BoxShadow(
                color: Color(0x55000000),
                offset: Offset(0, 6),
                blurRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              const CandyGloss(radius: 12),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (locked)
                        const Icon(Icons.lock, size: 20, color: Colors.white70)
                      else
                        Text(
                          '${widget.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            height: 1.1,
                            shadows: shadow,
                          ),
                        ),
                      Text(
                        '${widget.size}x${widget.size}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          shadows: shadow,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Icon(
                              i < widget.stars ? Icons.star : Icons.star_border,
                              size: 13,
                              color: i < widget.stars
                                  ? const Color(0xFFFFE066)
                                  : Colors.white60,
                              shadows: shadow,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
