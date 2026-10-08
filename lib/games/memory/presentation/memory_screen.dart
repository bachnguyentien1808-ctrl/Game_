import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/core/ui/glass.dart';
import 'package:puzzle_hub/core/ui/score_chip.dart';
import 'package:puzzle_hub/features/common/game_block.dart';
import 'package:puzzle_hub/features/common/game_overlays.dart';
import 'package:puzzle_hub/features/common/hub_panels.dart';
import 'package:puzzle_hub/games/memory/domain/memory_engine.dart';
import 'package:puzzle_hub/games/memory/presentation/memory_card_view.dart';

const _id = 'memory';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key, this.daily});

  /// Khoa ngay yyyyMMdd khi la thu thach ngay (luon 4x4, bo bieu tuong).
  final String? daily;

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen>
    with SingleTickerProviderStateMixin {
  late final GameStore _store = GameStore(
    ref.read(progressStoreProvider),
    daily: widget.daily,
  );
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late MemoryGame _game;
  Timer? _hideTimer;
  Timer? _peekTimer;
  Timer? _resultTimer;
  Timer? _clock;
  int _gen = 0;
  bool _paused = false;
  bool _peeking = false;
  bool _showResult = false;
  bool _newRecord = false;
  int? _points;
  final Set<int> _bad = {};

  bool get _isDaily => widget.daily != null;

  @override
  void initState() {
    super.initState();
    MemoryGame? restored;
    final saved = _store.loadState(_id);
    if (saved != null) {
      try {
        restored = MemoryGame.fromJson(saved);
      } on Object {
        restored = null;
      }
    }
    if (restored != null && !restored.won) {
      _game = restored;
      _intro.forward();
    } else {
      _game = _create(MemorySize.s4x4, MemorySet.icons);
      _intro.forward();
      if (!_isDaily) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openSetup();
        });
      }
    }
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused || _peeking || _game.won || !_game.started) {
        return;
      }
      setState(() => _game.seconds++);
      if (_game.seconds % 5 == 0) _save();
    });
  }

  MemoryGame _create(MemorySize size, MemorySet set) =>
      MemoryGame(size: size, set: set, rng: _store.rngFor(_id));

  void _save() {
    if (_game.won) return;
    _store.saveState(_id, _game.toJson());
  }

  void _cancelTimers() {
    _hideTimer?.cancel();
    _peekTimer?.cancel();
    _resultTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    _clock?.cancel();
    _intro.dispose();
    super.dispose();
  }

  void _startNew(MemorySize size, MemorySet set) {
    _cancelTimers();
    setState(() {
      _game = _create(size, set);
      _gen++;
      _paused = false;
      _peeking = false;
      _showResult = false;
      _newRecord = false;
      _points = null;
      _bad.clear();
    });
    _intro.forward(from: 0);
    _save();
  }

  Future<void> _openSetup() async {
    final r = await showModalBottomSheet<(MemorySize, MemorySet)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SetupSheet(size: _game.size, set: _game.set),
    );
    if (r != null && mounted) _startNew(r.$1, r.$2);
  }

  void _restart() {
    if (_isDaily) {
      _startNew(MemorySize.s4x4, MemorySet.icons);
    } else {
      _openSetup();
    }
  }

  bool get _locked => _paused || _peeking || _game.won;

  void _onTap(int i) {
    if (_locked || _game.waiting) return;
    final first = !_game.started;
    final r = _game.flip(i);
    if (r == FlipResult.ignored) return;
    if (first) _store.recordStart(_game.size.statsId);
    GameFx.tap();
    Sfx.play(SfxKind.flip);
    setState(() {});
    switch (r) {
      case FlipResult.match:
        GameFx.success();
        Sfx.play(SfxKind.match);
      case FlipResult.mismatch:
        GameFx.error();
        Sfx.play(SfxKind.error);
        final open = [
          for (var k = 0; k < _game.cards.length; k++)
            if (_game.cards[k].faceUp) k,
        ];
        setState(() => _bad.addAll(open));
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(milliseconds: 950), () {
          if (!mounted) return;
          setState(() {
            _game.hideMismatch();
            _bad.clear();
          });
          _save();
        });
      case FlipResult.first || FlipResult.ignored:
        break;
    }
    if (_game.won) {
      _onWin();
    } else {
      _save();
    }
  }

  void _onWin() {
    final g = _game;
    if (_points == null) {
      final pairs = g.size.pairs;
      final pts = Scoring.points(
        base: 800,
        seconds: g.seconds,
        parSeconds: pairs * 10,
        mult: max(0.5, pairs / 8),
        mistakes: max(0, g.moves - pairs) ~/ 2,
        hints: g.peeksUsed,
      );
      _points = pts;
      _store.awardPoints(_id, pts);
    }
    final prev = _store.stats(g.size.statsId).best;
    _newRecord = !_isDaily && (prev == null || g.moves < prev);
    if (_isDaily) {
      _store.recordWin(_id, score: g.moves);
    } else {
      _store.recordWin(g.size.statsId, score: g.moves, lowerIsBetter: true);
      if (g.size == MemorySize.s4x4) {
        _store.recordScore(_id, g.moves, lowerIsBetter: true);
      }
    }
    _store.clearState(_id);
    _resultTimer?.cancel();
    _resultTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      GameFx.success();
      Sfx.play(SfxKind.win);
      setState(() => _showResult = true);
    });
  }

  void _peek() {
    if (_locked || _game.waiting || !_game.usePeek()) return;
    Sfx.play(SfxKind.flip);
    setState(() => _peeking = true);
    _save();
    _peekTimer?.cancel();
    _peekTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _peeking = false);
    });
  }

  void _togglePause() {
    if (_game.won) return;
    setState(() => _paused = !_paused);
    if (_paused) _save();
  }

  static String _fmt(int sec) =>
      '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final best = _store.stats(_game.size.statsId).best;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: const [ScoreChip(), HubMenuAction()],
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: modestColumnWidth(context, 780),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                // Khoi rong hon, thap hon (khong keo cao het man hinh).
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 860),
                  child: GameBlock(
                    expand: true,
                    title: _isDaily ? 'Tìm cặp - Thử thách ngày' : 'Tìm cặp',
                    onBack: () => context.go(_store.homeRoute),
                    child: Column(
                      children: [
                        _statsRow(s, best),
                        const SizedBox(height: 10),
                        CandyRibbon(
                          text:
                              '${_game.size.label} · ${_game.size.pairs} cặp'
                              '${best == null ? '' : ' · Kỷ lục: $best lượt'}',
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _board(s)),
                        const SizedBox(height: 12),
                        GlassPanel(
                          padding: const EdgeInsets.all(10),
                          child: _actions(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          WinBanner(
            show: _showResult,
            title: 'Hoàn thành!',
            points: _points,
            subtitle:
                '${_game.moves} lượt · ${_fmt(_game.seconds)} · '
                '${_game.stars} sao',
          ),
          if (_showResult) _resultPanel(s),
        ],
      ),
    );
  }

  Widget _statsRow(ColorScheme s, int? best) {
    return GlassBar(
      children: [
        _Stat(
          Icons.timer_outlined,
          _fmt(_game.seconds),
          'Thời gian',
          Candy.blue,
        ),
        _Stat(Icons.touch_app_outlined, '${_game.moves}', 'Lượt', Candy.green),
        _Stat(
          Icons.local_fire_department,
          'x${_game.combo}',
          'Chuỗi',
          _game.combo >= 2 ? Candy.orange : Candy.purple,
        ),
      ],
    );
  }

  Widget _board(ColorScheme s) {
    final size = _game.size;
    return LayoutBuilder(
      builder: (context, box) {
        final gap = size.cols >= 6 ? 6.0 : 8.0;
        final cell = [
          (box.maxWidth - 30 - gap * (size.cols - 1)) / size.cols,
          (box.maxHeight - 34 - gap * (size.rows - 1)) / size.rows,
        ].reduce((a, b) => a < b ? a : b).clamp(20.0, 140.0);
        final w = cell * size.cols + gap * (size.cols - 1);
        final h = cell * size.rows + gap * (size.rows - 1);
        return Center(
          child: CandyFrame(
            padding: 6,
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  GridView.count(
                    crossAxisCount: size.cols,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < _game.cards.length; i++)
                        MemoryCardView(
                          key: ValueKey('memory-card-$_gen-$i'),
                          set: _game.set,
                          symbol: _game.cards[i].symbol,
                          visible:
                              !_paused &&
                              (_game.cards[i].faceUp ||
                                  _game.cards[i].matched ||
                                  _peeking),
                          matched: _game.cards[i].matched,
                          mismatch: _bad.contains(i),
                          intro: _intro,
                          index: i,
                          total: _game.cards.length,
                          onTap: () => _onTap(i),
                        ),
                    ],
                  ),
                  if (_paused)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: GlassStyle.of(context).inner,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.pause_circle,
                                size: 56,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Đã tạm dừng',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              CandyButton(
                                key: const ValueKey('memory-resume'),
                                colors: Candy.green,
                                onPressed: _togglePause,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow),
                                    SizedBox(width: 6),
                                    Text('Tiếp tục'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actions() {
    final canPeek = !_locked && !_game.waiting && _game.peeksLeft > 0;
    final canPause = !_game.won;
    final compact = MediaQuery.sizeOf(context).width < 480;
    return Row(
      children: [
        Expanded(
          child: CandyButton(
            key: const ValueKey('memory-peek'),
            onPressed: canPeek ? _peek : null,
            colors: Candy.purple,
            dim: !canPeek,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility_outlined),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    compact
                        ? '${_game.peeksLeft}'
                        : 'Nhìn trước (${_game.peeksLeft})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CandyButton(
            key: const ValueKey('memory-pause'),
            onPressed: canPause ? _togglePause : null,
            colors: Candy.orange,
            dim: !canPause,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_paused ? Icons.play_arrow : Icons.pause),
                if (!compact) const SizedBox(width: 6),
                if (!compact)
                  Flexible(
                    child: Text(
                      _paused ? 'Tiếp tục' : 'Tạm dừng',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Tooltip(
            message: _isDaily ? 'Chơi lại cùng đề' : 'Ván mới',
            child: CandyButton(
              key: const ValueKey('memory-new'),
              onPressed: _restart,
              colors: Candy.green,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded),
                  if (!compact) const SizedBox(width: 6),
                  if (!compact)
                    Flexible(
                      child: Text(
                        _isDaily ? 'Chơi lại' : 'Ván mới',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultPanel(ColorScheme s) {
    return Align(
      alignment: const Alignment(0, 0.82),
      child: PopIn(
        child: CandyFrame(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 1; i <= 3; i++)
                      Icon(
                        i <= _game.stars ? Icons.star : Icons.star_border,
                        key: ValueKey('memory-star-$i'),
                        size: 36,
                        color: Colors.amber,
                      ),
                  ],
                ),
                if (_newRecord)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: CandyRibbon(
                      text: 'Kỷ lục mới! ${_game.moves} lượt',
                      colors: Candy.orange,
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    CandyButton(
                      key: const ValueKey('memory-again'),
                      colors: Candy.green,
                      onPressed: _restart,
                      child: Text(_isDaily ? 'Chơi lại' : 'Ván mới'),
                    ),
                    CandyButton(
                      colors: Candy.red,
                      onPressed: () => context.go(_store.homeRoute),
                      child: const Text('Thoát'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.label, this.colors);

  final IconData icon;
  final String value;
  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: GlassStat(icon: icon, text: value, colors: colors),
    );
  }
}

class _SetupSheet extends StatefulWidget {
  const _SetupSheet({required this.size, required this.set});

  final MemorySize size;
  final MemorySet set;

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  late MemorySize _size = widget.size;
  late MemorySet _set = widget.set;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kích thước', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final z in MemorySize.values)
                  ChoiceChip(
                    key: ValueKey('memory-size-${z.label}'),
                    label: Text('${z.label} · ${z.pairs} cặp'),
                    selected: z == _size,
                    onSelected: (_) => setState(() => _size = z),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Bộ hình', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final z in MemorySet.values)
                  ChoiceChip(
                    key: ValueKey('memory-set-${z.name}'),
                    label: Text(z.title),
                    selected: z == _set,
                    onSelected: (_) => setState(() => _set = z),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: CandyButton(
                key: const ValueKey('memory-start'),
                colors: Candy.green,
                onPressed: () => Navigator.pop(context, (_size, _set)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow),
                    SizedBox(width: 6),
                    Text('Bắt đầu'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
