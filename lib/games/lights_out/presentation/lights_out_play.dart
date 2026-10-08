import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/core/ui/glass.dart';
import 'package:puzzle_hub/core/ui/score_chip.dart';
import 'package:puzzle_hub/features/common/game_block.dart';
import 'package:puzzle_hub/features/common/game_overlays.dart';
import 'package:puzzle_hub/features/common/hub_panels.dart';
import 'package:puzzle_hub/games/lights_out/domain/lights_out_engine.dart';
import 'package:puzzle_hub/games/lights_out/domain/lights_out_levels.dart';

const lightsOutId = 'lights_out';
const _levelStateId = 'lights_out.level';
const levelsStateId = 'lights_out.levels';

enum LightsMode { level, random, daily }

/// Cach vao mot van: man chon, ngau nhien (kich thuoc / tiep tuc), thu thach ngay.
@immutable
class LightsSession {
  const LightsSession.level(this.level)
    : mode = LightsMode.level,
      size = 0,
      resume = false;
  const LightsSession.random(this.size, {this.resume = false})
    : mode = LightsMode.random,
      level = 0;
  const LightsSession.daily()
    : mode = LightsMode.daily,
      size = 5,
      level = 0,
      resume = true;

  final LightsMode mode;
  final int level;
  final int size;
  final bool resume;

  @override
  bool operator ==(Object other) =>
      other is LightsSession &&
      other.mode == mode &&
      other.level == level &&
      other.size == size &&
      other.resume == resume;

  @override
  int get hashCode => Object.hash(mode, level, size, resume);
}

/// Sao da dat theo tung man (do dai = so man; 0 = chua qua).
List<int> loadLevelStars(GameStore store) {
  final out = List<int>.filled(LightsOutLevels.count, 0);
  try {
    final l = store.loadState(levelsStateId)?['stars'] as List?;
    if (l != null) {
      for (var i = 0; i < out.length && i < l.length; i++) {
        out[i] = (l[i] as int).clamp(0, 3);
      }
    }
  } on Object {
    // du lieu hong: coi nhu chua co tien do
  }
  return out;
}

/// Man choi mot van Tat den (man chon, ngau nhien hoac thu thach ngay).
class LightsOutPlay extends StatefulWidget {
  const LightsOutPlay({
    required this.session,
    required this.store,
    required this.onExit,
    this.onNextLevel,
    super.key,
  });

  final LightsSession session;
  final GameStore store;

  /// Thoat ra man chon / man chinh.
  final VoidCallback onExit;

  /// Sang man ke tiep (chi che do man chon, khi con man).
  final VoidCallback? onNextLevel;

  @override
  State<LightsOutPlay> createState() => _LightsOutPlayState();
}

class _LightsOutPlayState extends State<LightsOutPlay> {
  late LightsOut _game;
  late List<List<bool>> _shown;
  final _timers = <Timer>[];
  int? _hint;
  bool _won = false;
  bool _banner = false;
  int _stars = 0;
  int _starsShown = 0;
  int? _points;
  final Stopwatch _clock = Stopwatch();

  GameStore get _store => widget.store;
  LightsSession get _s => widget.session;
  String get _stateId =>
      _s.mode == LightsMode.level ? _levelStateId : lightsOutId;
  bool get _reduce => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    LightsOut? restored;
    final saved = _s.resume || _s.mode == LightsMode.level
        ? _store.loadState(_stateId)
        : null;
    if (saved != null) {
      try {
        final g = LightsOut.fromJson(saved);
        final okLevel =
            _s.mode != LightsMode.level || saved['level'] == _s.level;
        final okSize = _s.mode != LightsMode.daily || g.size == 5;
        if (okLevel && okSize && !g.solved) restored = g;
      } on Object {
        restored = null;
      }
    }
    if (restored != null) {
      _game = restored;
    } else {
      _game = _newGame();
      _store.recordStart(lightsOutId);
      if (_s.mode == LightsMode.random) {
        _store.recordStart('$lightsOutId.${_game.size}');
      }
      _save();
    }
    _shown = [for (final r in _game.cells) List.of(r)];
  }

  LightsOut _newGame() => switch (_s.mode) {
    LightsMode.level => LightsOutLevels.build(_s.level),
    LightsMode.daily => LightsOut.generate(rng: _store.rngFor(lightsOutId)),
    LightsMode.random => LightsOut.generate(size: _s.size),
  };

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _later(Duration d, VoidCallback f) {
    _timers.add(
      Timer(d, () {
        if (mounted) f();
      }),
    );
  }

  void _save() {
    final j = _game.toJson();
    if (_s.mode == LightsMode.level) j['level'] = _s.level;
    _store.saveState(_stateId, j);
  }

  void _syncAll() {
    _cancelTimers();
    _shown = [for (final r in _game.cells) List.of(r)];
  }

  void _syncCell(int r, int c) {
    if (r < 0 || c < 0 || r >= _game.size || c >= _game.size) return;
    setState(() => _shown[r][c] = _game.cells[r][c]);
  }

  /// O bam doi ngay, 4 o ke dao tre mot nhip tao hieu ung song lan nhe.
  void _animatePress(int r, int c) {
    _shown[r][c] = _game.cells[r][c];
    final fast = _reduce;
    for (final (dr, dc) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nc < 0 || nr >= _game.size || nc >= _game.size) continue;
      if (fast) {
        _shown[nr][nc] = _game.cells[nr][nc];
      } else {
        _later(const Duration(milliseconds: 70), () => _syncCell(nr, nc));
      }
    }
  }

  void _tap(int r, int c) {
    if (_won) return;
    _clock.start();
    setState(() {
      _game.press(r, c);
      _hint = null;
      _animatePress(r, c);
    });
    GameFx.tap();
    Sfx.play(SfxKind.tap);
    if (_game.solved) {
      _win();
    } else {
      _save();
    }
  }

  void _win() {
    _won = true;
    final opt = _game.optimal ?? _game.moves;
    _stars = LightsOutLevels.stars(_game.moves, opt);
    switch (_s.mode) {
      case LightsMode.level:
        _store.recordWin(lightsOutId);
        final stars = loadLevelStars(_store);
        if (_stars > stars[_s.level - 1]) stars[_s.level - 1] = _stars;
        _store.saveState(levelsStateId, {'stars': stars});
      case LightsMode.random:
        final n = _game.size;
        _store
          ..recordWin(
            lightsOutId,
            score: n == 5 ? _game.moves : null,
            lowerIsBetter: true,
          )
          ..recordWin(
            '$lightsOutId.$n',
            score: _game.moves,
            lowerIsBetter: true,
          );
      case LightsMode.daily:
        _store.recordWin(lightsOutId, score: _game.moves, lowerIsBetter: true);
    }
    _clock.stop();
    final size = _game.size;
    final mult = switch (size) {
      3 => 0.6,
      4 => 0.9,
      5 => 1.3,
      _ => 1.8,
    };
    final pts = Scoring.points(
      base: 800,
      seconds: _clock.elapsed.inSeconds,
      parSeconds: size * size * 6,
      mult: mult,
      mistakes: max(0, _game.moves - opt) ~/ 2,
      hints: _game.hintsUsed,
    );
    _points = pts;
    _store.awardPoints(lightsOutId, pts);
    _store.clearState(_stateId);
    GameFx.success();
    Sfx.play(SfxKind.win);
    _winSequence();
  }

  /// Toan ban sang lan luot theo duong cheo, tat hang, roi hien banner + sao.
  void _winSequence() {
    if (_reduce) {
      setState(() {
        _banner = true;
        _starsShown = _stars;
      });
      return;
    }
    final n = _game.size;
    const step = 55;
    const base = 160;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        _later(
          Duration(milliseconds: base + (r + c) * step),
          () => setState(() => _shown[r][c] = true),
        );
      }
    }
    final lit = base + (2 * n - 2) * step + 300;
    _later(Duration(milliseconds: lit), () {
      setState(() {
        for (final row in _shown) {
          row.fillRange(0, n, false);
        }
      });
    });
    final show = lit + 450;
    _later(Duration(milliseconds: show), () => setState(() => _banner = true));
    for (var i = 1; i <= _stars; i++) {
      _later(Duration(milliseconds: show + 350 * i), () {
        setState(() => _starsShown = i);
        Sfx.play(SfxKind.success);
      });
    }
  }

  void _undo() {
    if (_won || _game.undo() == null) return;
    setState(() {
      _hint = null;
      _syncAll();
    });
    GameFx.tap();
    Sfx.play(SfxKind.erase);
    _save();
  }

  void _redo() {
    if (_won || _game.redo() == null) return;
    setState(() {
      _hint = null;
      _syncAll();
    });
    GameFx.tap();
    Sfx.play(SfxKind.tap);
    _save();
  }

  void _showHint() {
    if (_won || _hint != null) return;
    final h = _game.useHint();
    if (h == null) {
      GameFx.error();
      Sfx.play(SfxKind.error);
      return;
    }
    setState(() => _hint = h);
    GameFx.tap();
    Sfx.play(SfxKind.place);
    _save();
  }

  /// Van moi (ngau nhien) hoac choi lai cung de (man chon, thu thach ngay).
  void _restart() {
    _cancelTimers();
    setState(() {
      if (_s.mode == LightsMode.random) {
        _game = _newGame();
        _store
          ..recordStart(lightsOutId)
          ..recordStart('$lightsOutId.${_game.size}');
      } else {
        _game.reset();
      }
      _won = false;
      _points = null;
      _clock
        ..stop()
        ..reset();
      _banner = false;
      _starsShown = 0;
      _hint = null;
      _shown = [for (final r in _game.cells) List.of(r)];
    });
    _save();
  }

  String get _title => switch (_s.mode) {
    LightsMode.level => 'Màn ${_s.level}',
    LightsMode.daily => 'Tắt đèn - Thử thách ngày',
    LightsMode.random => 'Tắt đèn ${_game.size}x${_game.size}',
  };

  @override
  Widget build(BuildContext context) {
    final best = _s.mode == LightsMode.level
        ? null
        : _store.stats('$lightsOutId.${_game.size}').best;
    final reduce = MediaQuery.of(context).disableAnimations;
    return CandyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          actions: const [ScoreChip(), HubMenuAction()],
        ),
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: modestColumnWidth(context, 680),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  // Khoi rong hon, thap hon (khong keo cao het man hinh).
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 700),
                    child: GameBlock(
                      expand: true,
                      title: _title,
                      onBack: widget.onExit,
                      child: Column(
                        children: [
                          GlassBar(
                            children: [
                              _stat(
                                Icons.touch_app_outlined,
                                Candy.blue,
                                'Lượt ${_game.moves}',
                              ),
                              _stat(
                                Icons.flag_outlined,
                                Candy.green,
                                'Tối ưu ${_game.optimal ?? '?'}',
                              ),
                              if (best != null)
                                _stat(
                                  Icons.emoji_events_outlined,
                                  Candy.orange,
                                  'Kỷ lục $best',
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Flexible(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: CandyFrame(
                                  child: _Board(
                                    shown: _shown,
                                    hint: _hint,
                                    reduce: reduce,
                                    onTap: _tap,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (!_won)
                            GlassPanel(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _action(
                                    Icons.undo,
                                    'Hoàn tác',
                                    Candy.blue,
                                    _game.canUndo ? _undo : null,
                                  ),
                                  _action(
                                    Icons.redo,
                                    'Làm lại bước',
                                    Candy.indigo,
                                    _game.canRedo ? _redo : null,
                                  ),
                                  _action(
                                    Icons.tips_and_updates_outlined,
                                    'Gợi ý (còn ${_game.hintsLeft})',
                                    Candy.orange,
                                    _game.hintsLeft > 0 && _hint == null
                                        ? _showHint
                                        : null,
                                    badge: '${_game.hintsLeft}',
                                  ),
                                  _action(
                                    Icons.refresh_rounded,
                                    _s.mode == LightsMode.random
                                        ? 'Ván mới'
                                        : 'Chơi lại ván',
                                    Candy.green,
                                    _restart,
                                  ),
                                ],
                              ),
                            )
                          else if (_banner)
                            GlassPanel(
                              child: Row(
                                children: [
                                  if (_s.mode == LightsMode.level &&
                                      widget.onNextLevel != null) ...[
                                    Expanded(
                                      child: CandyButton(
                                        onPressed: widget.onNextLevel,
                                        colors: Candy.green,
                                        child: const Text('Màn kế tiếp'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: CandyButton(
                                      onPressed: widget.onExit,
                                      child: Text(
                                        _s.mode == LightsMode.level
                                            ? 'Danh sách màn'
                                            : 'Thoát',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const SizedBox(height: 40),
                          const SizedBox(height: 10),
                          const CandyRibbon(
                            text: 'Bấm một ô sẽ đảo ô đó và 4 ô kề bên',
                            colors: Candy.indigo,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_banner)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: const Alignment(0, -0.62),
                    child: _StarsRow(shown: _starsShown, total: 3),
                  ),
                ),
              ),
            Positioned.fill(
              child: WinBanner(
                show: _banner,
                points: _points,
                title: 'Tắt hết đèn!',
                subtitle:
                    '${_game.moves} lượt (tối ưu ${_game.optimal ?? '?'})',
                onAgain: _restart,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, List<Color> colors, String text) {
    return Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: GlassStat(icon: icon, colors: colors, text: text),
      ),
    );
  }

  /// Nut tron nho chi co bieu tuong; di chuot vao se hien chu (tooltip).
  Widget _action(
    IconData icon,
    String label,
    List<Color> colors,
    VoidCallback? onPressed, {
    String? badge,
  }) {
    return Badge(
      isLabelVisible: badge != null,
      label: badge == null ? null : Text(badge),
      child: Tooltip(
        message: label,
        child: CandyButton(
          onPressed: onPressed,
          colors: colors,
          dim: onPressed == null,
          circle: true,
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.shown, required this.total});

  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          i < shown
              ? PopIn(
                  key: ValueKey('on$i'),
                  duration: const Duration(milliseconds: 360),
                  child: const Icon(Icons.star, size: 44, color: Colors.amber),
                )
              : Icon(
                  Icons.star_border,
                  size: 44,
                  color: Theme.of(context).colorScheme.outline
                      .withValues(alpha: 0.6),
                ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.shown,
    required this.hint,
    required this.reduce,
    required this.onTap,
  });

  final List<List<bool>> shown;
  final int? hint;
  final bool reduce;
  final void Function(int r, int c) onTap;

  @override
  Widget build(BuildContext context) {
    final n = shown.length;
    final gap = n >= 6 ? 3.0 : 4.0;
    return Column(
      children: [
        for (var r = 0; r < n; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < n; c++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(gap),
                      child: _Cell(
                        key: ValueKey('lo_cell_${r}_$c'),
                        lit: shown[r][c],
                        hint: hint == r * n + c,
                        reduce: reduce,
                        onTap: () => onTap(r, c),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatefulWidget {
  const _Cell({
    required this.lit,
    required this.hint,
    required this.reduce,
    required this.onTap,
    super.key,
  });

  final bool lit;
  final bool hint;
  final bool reduce;
  final VoidCallback onTap;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  bool _down = false;

  @override
  void didUpdateWidget(_Cell old) {
    super.didUpdateWidget(old);
    if (old.lit != widget.lit && !widget.reduce) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lit = widget.lit;
    final dur = widget.reduce
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return LayoutBuilder(
      builder: (_, box) {
        final side = box.biggest.shortestSide;
        final radius = BorderRadius.circular(side * 0.32);
        final gem = AnimatedContainer(
          duration: dur,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: lit ? const Color(0xFFFFF3B0) : const Color(0xFF0E2233),
              width: 2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: lit
                  ? const [
                      Color(0xFFFFF176),
                      Color(0xFFFFB300),
                      Color(0xFFFF8F00),
                    ]
                  : const [Color(0xFF16293B), Color(0xFF2A4560)],
            ),
            boxShadow: lit
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.75),
                      blurRadius: side * 0.45,
                      spreadRadius: side * 0.05,
                    ),
                    const BoxShadow(
                      color: Color(0xFFC46A00),
                      offset: Offset(0, 3),
                    ),
                  ]
                : const [
                    BoxShadow(color: Color(0x33FFFFFF), offset: Offset(0, 1.5)),
                  ],
          ),
          child: Stack(
            children: [
              if (lit) CandyGloss(radius: side * 0.28, opacity: 0.5),
              Center(
                child: AnimatedScale(
                  duration: dur,
                  curve: Curves.easeOutBack,
                  scale: lit ? 1 : 0.7,
                  child: Icon(
                    lit ? Icons.lightbulb : Icons.lightbulb_outline,
                    size: side * 0.5,
                    color: lit
                        ? Colors.white
                        : const Color(0xFF6C8AA6).withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pop,
                  builder: (_, child) {
                    final k = _pop.isAnimating
                        ? 1 + 0.16 * sin(_pop.value * pi)
                        : 1.0;
                    return Transform.scale(scale: k, child: child);
                  },
                  child: AnimatedScale(
                    scale: _down ? 0.88 : 1,
                    duration: const Duration(milliseconds: 80),
                    child: gem,
                  ),
                ),
              ),
              if (widget.hint)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _PulseRing(
                      color: const Color(0xFF7CF5FF),
                      radius: radius,
                      animate: !widget.reduce,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({
    required this.color,
    required this.radius,
    required this.animate,
  });

  final Color color;
  final BorderRadius radius;
  final bool animate;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Transform.scale(
        scale: 1 + 0.06 * _c.value,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.radius,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.5 + 0.5 * _c.value),
              width: 3,
            ),
          ),
        ),
      ),
    );
  }
}
