import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:puzzle_hub/games/game2048/domain/game2048_engine.dart';

const _id = '2048';

/// Id thong ke theo kich thuoc: 4x4 dung '2048' (man chinh doc id nay),
/// 3x3 va 5x5 dung '2048.3' / '2048.5'.
String statIdFor(int size) => size == 4 ? _id : '$_id.$size';

class _Tile {
  _Tile(this.id, this.value, this.r, this.c, {this.fresh = false});
  final int id;
  int value;
  int r;
  int c;
  int bump = 0;
  bool fresh;
  bool dying = false;
}

class _Float {
  _Float(this.key, this.text, this.r, this.c);
  final int key;
  final String text;
  final int r;
  final int c;
}

class Game2048Screen extends ConsumerStatefulWidget {
  const Game2048Screen({super.key, this.rng});

  /// Chi dung cho test (Random co seed).
  @visibleForTesting
  final Random? rng;

  @override
  ConsumerState<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends ConsumerState<Game2048Screen> {
  static const _slideMs = 120;
  late final Random _rng = widget.rng ?? Random();
  final _focus = FocusNode();
  late final GameStore _store = GameStore(ref.read(progressStoreProvider));
  final _timers = <Timer>[];
  late Game2048 _g;
  var _tiles = <_Tile>[];
  final _floats = <_Float>[];
  var _nextId = 1;
  var _busy = false;
  var _confetti = false;
  final _sw = Stopwatch();
  int? _points;
  var _panX = 0.0;
  var _panY = 0.0;
  var _panDone = false;

  static final Map<LogicalKeyboardKey, Dir> _keys = {
    LogicalKeyboardKey.arrowLeft: Dir.left,
    LogicalKeyboardKey.arrowRight: Dir.right,
    LogicalKeyboardKey.arrowUp: Dir.up,
    LogicalKeyboardKey.arrowDown: Dir.down,
    LogicalKeyboardKey.keyA: Dir.left,
    LogicalKeyboardKey.keyD: Dir.right,
    LogicalKeyboardKey.keyW: Dir.up,
    LogicalKeyboardKey.keyS: Dir.down,
  };

  @override
  void initState() {
    super.initState();
    final saved = _store.loadState(_id);
    Game2048? restored;
    if (saved != null) {
      try {
        restored = Game2048.fromJson(saved);
      } on Object {
        restored = null;
      }
    }
    if (restored != null && !restored.isOver) {
      _g = restored;
      _rebuildTiles(fresh: false);
    } else {
      _g = Game2048.start(rng: _rng);
      _rebuildTiles(fresh: true);
      _store
        ..recordStart(statIdFor(_g.size))
        ..saveState(_id, _g.toJson());
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _focus.dispose();
    super.dispose();
  }

  void _later(int ms, VoidCallback fn) {
    late final Timer t;
    t = Timer(Duration(milliseconds: ms), () {
      _timers.remove(t);
      if (mounted) fn();
    });
    _timers.add(t);
  }

  bool get _animate => !MediaQuery.disableAnimationsOf(context);

  void _rebuildTiles({required bool fresh}) {
    _tiles = [];
    final cells = _g.board.cells;
    for (var r = 0; r < _g.size; r++) {
      for (var c = 0; c < _g.size; c++) {
        if (cells[r][c] != 0) {
          _tiles.add(_Tile(_nextId++, cells[r][c], r, c, fresh: fresh));
        }
      }
    }
    _floats.clear();
  }

  void _save() {
    if (_g.isOver) {
      _store.clearState(_id);
    } else {
      _store.saveState(_id, _g.toJson());
    }
  }

  void _move(Dir d) {
    if (_busy || (_g.won && !_g.continued) || _g.isOver) return;
    final out = _g.move(d, _rng);
    if (out == null) return;
    if (!_sw.isRunning) _sw.start();
    final ms = _animate ? _slideMs : 0;
    _busy = true;
    _later(ms, () => _busy = false);

    final byPos = <int, _Tile>{for (final t in _tiles) t.r * 100 + t.c: t};
    final dest = <int, _Tile>{};
    final dying = <_Tile>[];
    for (final m in out.slide.moves) {
      final t = byPos[m.fromR * 100 + m.fromC]!;
      t
        ..r = m.toR
        ..c = m.toC
        ..fresh = false;
      final key = m.toR * 100 + m.toC;
      if (m.merged) {
        t.dying = true;
        dying.add(t);
        final s = dest[key]!;
        s.value *= 2;
        s.bump++;
      } else {
        dest[key] = t;
      }
    }
    final sp = out.spawn;
    if (sp != null) {
      _tiles.add(_Tile(_nextId++, sp.value, sp.r, sp.c, fresh: true));
    }
    if (out.slide.gain > 0) {
      final merges = out.slide.merges;
      final top = merges.reduce((a, b) => a.$3 >= b.$3 ? a : b);
      final f = _Float(_nextId++, '+${out.slide.gain}', top.$1, top.$2);
      _floats.add(f);
      _later(750, () => setState(() => _floats.remove(f)));
    }
    setState(() {});
    _later(ms, () {
      setState(() => _tiles.removeWhere((t) => t.dying));
    });

    if (out.slide.merges.isNotEmpty) {
      GameFx.success();
      Sfx.play(SfxKind.merge);
    } else {
      GameFx.tap();
    }
    final sid = statIdFor(_g.size);
    _store.recordScore(sid, _g.score);
    if (out.justWon) {
      _store.recordWin(sid, score: _g.score);
      _awardWin();
      Sfx.play(SfxKind.win);
      _confetti = true;
    }
    _save();
    if (_g.isOver && !out.justWon) Sfx.play(SfxKind.error);
  }

  void _awardWin() {
    if (_points != null) return;
    _sw.stop();
    final pts = Scoring.points(
      base: 1000,
      seconds: _sw.elapsed.inSeconds,
      parSeconds: 480,
      mult: switch (_g.size) {
        3 => 1.5,
        4 => 1.0,
        _ => 0.7,
      },
      hints: Game2048.maxUndos - _g.undosLeft,
    );
    _points = pts;
    _store.awardPoints(_id, pts);
  }

  void _undo() {
    if (!_g.undo()) return;
    GameFx.tap();
    Sfx.play(SfxKind.erase);
    setState(() => _rebuildTiles(fresh: false));
    _save();
  }

  void _restart({int? size}) {
    setState(() {
      _g = Game2048.start(size: size ?? _g.size, rng: _rng);
      _rebuildTiles(fresh: true);
      _confetti = false;
      _busy = false;
      _points = null;
      _sw
        ..stop()
        ..reset();
    });
    _store
      ..recordStart(statIdFor(_g.size))
      ..saveState(_id, _g.toJson());
  }

  bool get _inProgress => _g.score > 0 && !_g.isOver;

  Future<void> _askNewGame({int? size}) async {
    if (_inProgress) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ván mới?'),
          content: const Text('Ván đang chơi sẽ bị bỏ.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Giữ lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Chơi mới'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    _restart(size: size);
  }

  Future<void> _pickSize() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Candy.bgTop,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final n in const [3, 4, 5])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CandyButton(
                    key: ValueKey('size$n'),
                    colors: switch (n) {
                      3 => Candy.green,
                      4 => Candy.blue,
                      _ => Candy.purple,
                    },
                    dim: n != _g.size,
                    onPressed: () => Navigator.pop(ctx, n),
                    child: SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          Icon(
                            n == _g.size
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$n x $n',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                Text(
                                  'Kỷ lục ${_store.stats(statIdFor(n)).best ?? 0} - đích ${Game2048.targetFor(n)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
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
    if (picked == null || picked == _g.size || !mounted) return;
    await _askNewGame(size: picked);
  }

  void _continue() {
    setState(() {
      _g.continued = true;
      _confetti = false;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final won = _g.won && !_g.continued;
    final over = _g.isOver;
    final best = max(_store.stats(statIdFor(_g.size)).best ?? 0, _g.score);
    return CandyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          actions: const [ScoreChip(), HubMenuAction()],
        ),
        body: KeyboardListener(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: (e) {
            final d = _keys[e.logicalKey];
            if (e is KeyDownEvent && d != null) _move(d);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {
              _panX = 0;
              _panY = 0;
              _panDone = false;
            },
            onPanUpdate: (u) {
              if (_panDone) return;
              _panX += u.delta.dx;
              _panY += u.delta.dy;
              if (max(_panX.abs(), _panY.abs()) < 24) return;
              _panDone = true;
              _move(
                _panX.abs() > _panY.abs()
                    ? (_panX > 0 ? Dir.right : Dir.left)
                    : (_panY > 0 ? Dir.down : Dir.up),
              );
            },
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: modestColumnWidth(context, 660),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      // Khoi rong hon va khong keo cao het man hinh.
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: modestColumnWidth(context, 660) + 240,
                        ),
                        child: GameBlock(
                          expand: true,
                          title: '2048  ${_g.size}x${_g.size}',
                          onBack: () => context.go('/'),
                          child: Column(
                            children: [
                              GlassBar(
                                children: [
                                  _Stat(
                                    label: 'Điểm',
                                    icon: Icons.star,
                                    colors: Candy.orange,
                                    value: _g.score,
                                    animate: _animate,
                                  ),
                                  _Stat(
                                    label: 'Cao nhất',
                                    icon: Icons.emoji_events,
                                    colors: Candy.purple,
                                    value: best,
                                    animate: false,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Center(
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: _board(won, over),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GlassPanel(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Badge.count(
                                      count: _g.undosLeft,
                                      child: _roundBtn(
                                        Icons.undo,
                                        Candy.blue,
                                        _g.canUndo ? _undo : null,
                                        'Hoàn tác (còn ${_g.undosLeft})',
                                        const ValueKey('undo'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    _roundBtn(
                                      Icons.grid_view,
                                      Candy.orange,
                                      _pickSize,
                                      'Kích thước bàn',
                                      const ValueKey('size'),
                                    ),
                                    const SizedBox(width: 16),
                                    _roundBtn(
                                      Icons.refresh,
                                      Candy.green,
                                      _askNewGame,
                                      'Ván mới',
                                      const ValueKey('restart'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              CandyRibbon(
                                text:
                                    'Vuốt hoặc dùng mũi tên / WASD. Đích: ${_g.target}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: Confetti(show: _confetti)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundBtn(
    IconData icon,
    List<Color> colors,
    VoidCallback? onTap,
    String tip,
    Key key,
  ) {
    return Tooltip(
      message: tip,
      child: CandyButton(
        key: key,
        colors: colors,
        dim: onTap == null,
        circle: true,
        padding: const EdgeInsets.all(10),
        onPressed: onTap,
        child: Icon(icon, size: 26),
      ),
    );
  }

  Widget _board(bool won, bool over) {
    const gap = 8.0;
    final n = _g.size;
    final dur = Duration(milliseconds: _animate ? _slideMs : 0);
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth - 2 * (6 + 3 + 4);
        final cell = (side - gap * (n + 1)) / n;
        double pos(int i) => gap + i * (cell + gap);
        final sorted = [..._tiles]
          ..sort((a, b) => (b.dying ? 1 : 0) - (a.dying ? 1 : 0));
        return CandyFrame(
          padding: 6,
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var r = 0; r < n; r++)
                  for (var c = 0; c < n; c++)
                    Positioned(
                      left: pos(c),
                      top: pos(r),
                      width: cell,
                      height: cell,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                for (final t in sorted)
                  AnimatedPositioned(
                    key: ValueKey('tile${t.id}'),
                    duration: dur,
                    curve: Curves.easeOut,
                    left: pos(t.c),
                    top: pos(t.r),
                    width: cell,
                    height: cell,
                    child: _TileView(
                      key: ValueKey('v${t.id}.${t.bump}'),
                      value: t.value,
                      bump: t.bump,
                      fresh: t.fresh,
                      animate: _animate,
                      cell: cell,
                    ),
                  ),
                for (final f in _floats)
                  Positioned(
                    key: ValueKey('float${f.key}'),
                    left: pos(f.c),
                    top: pos(f.r),
                    width: cell,
                    height: cell,
                    child: IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: _animate ? 700 : 1),
                        builder: (_, v, _) => Opacity(
                          opacity: (1 - v).clamp(0, 1),
                          child: Transform.translate(
                            offset: Offset(0, -cell * 0.9 * v),
                            child: Center(
                              child: Text(
                                f.text,
                                style: TextStyle(
                                  fontSize: cell * 0.3,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 4,
                                    ),
                                    Shadow(color: Candy.gold, blurRadius: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: _animate ? 600 : 0),
                    child: won
                        ? _Overlay(
                            key: const ValueKey('won'),
                            title: 'Đã đạt ${_g.target}!',
                            points: _points,
                            primaryLabel: 'Tiếp tục',
                            onPrimary: _continue,
                            secondaryLabel: 'Ván mới',
                            onSecondary: _restart,
                          )
                        : over
                        ? _Overlay(
                            key: const ValueKey('over'),
                            title: 'Hết nước đi',
                            primaryLabel: 'Chơi lại',
                            onPrimary: _restart,
                            secondaryLabel: _g.canUndo ? 'Hoàn tác' : null,
                            onSecondary: _g.canUndo ? _undo : null,
                          )
                        : const SizedBox.shrink(key: ValueKey('none')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.title,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.points,
    super.key,
  });

  final String title;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final int? points;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        // Tieu de + nut gom chung trong mot khoi thong bao.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: CandyFrame(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CandyRibbon(text: title, colors: Candy.orange),
                    if (points != null && points! > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        '+${Scoring.format(points!)} điểm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        CandyButton(
                          colors: Candy.green,
                          onPressed: onPrimary,
                          child: Text(primaryLabel),
                        ),
                        if (secondaryLabel != null)
                          CandyButton(
                            onPressed: onSecondary,
                            child: Text(secondaryLabel!),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vien thuoc kinh (nhu GlassStat) co nhan nho phia tren so.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.icon,
    required this.colors,
    required this.value,
    required this.animate,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final int value;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final g = GlassStyle.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
      decoration: BoxDecoration(
        color: g.pill,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: g.pillText.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
              TweenAnimationBuilder<int>(
                tween: IntTween(end: value),
                duration: Duration(milliseconds: animate ? 300 : 0),
                builder: (_, v, _) => Text(
                  '$v',
                  style: TextStyle(
                    color: g.pillText,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _lime = [Color(0xFFD9F55E), Color(0xFF86B818)];
const _yellow = [Color(0xFFFFE867), Color(0xFFF0B000)];
const _gold = [Color(0xFFFFE680), Color(0xFFE09A00)];

/// Gradient keo theo gia tri o.
List<Color> tileGradient(int v) {
  switch (v) {
    case 2:
      return const [Color(0xFF7FD8FF), Color(0xFF1E8BE8)];
    case 4:
      return Candy.teal;
    case 8:
      return Candy.green;
    case 16:
      return _lime;
    case 32:
      return _yellow;
    case 64:
      return Candy.orange;
    case 128:
      return Candy.red;
    case 256:
      return Candy.pink;
    case 512:
      return Candy.purple;
    case 1024:
      return Candy.indigo;
    case 2048:
      return _gold;
  }
  // > 2048: vang dam, doi mau nhe theo gia tri.
  return v > 2048 ? const [Color(0xFF3B2A6B), Color(0xFF16102E)] : Candy.blue;
}

class _TileView extends StatelessWidget {
  const _TileView({
    required this.value,
    required this.bump,
    required this.fresh,
    required this.animate,
    required this.cell,
    super.key,
  });

  final int value;
  final int bump;
  final bool fresh;
  final bool animate;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final colors = tileGradient(value);
    final digits = '$value'.length;
    final font =
        cell *
        switch (digits) {
          <= 2 => 0.5,
          3 => 0.4,
          4 => 0.32,
          _ => 0.26,
        };
    final radius = (cell * 0.16).clamp(6.0, 14.0);
    final glow = value >= 2048;
    final body = Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(color: Candy.deep(colors), offset: const Offset(0, 3)),
            if (glow)
              BoxShadow(
                color: const Color(0xFFFFD54A).withValues(alpha: 0.85),
                blurRadius: 16,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Stack(
          children: [
            CandyGloss(radius: radius * 0.8),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: FittedBox(
                  child: Text(
                    '$value',
                    style: TextStyle(
                      fontSize: font,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Color(0xAA000000),
                          blurRadius: 3,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!animate || (!fresh && bump == 0)) return body;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (_, t, child) {
        final scale = bump > 0
            ? (t < 0.4 ? 1.0 : 1 + 0.18 * sin((t - 0.4) / 0.6 * pi))
            : (t < 0.4 ? 0.0 : Curves.easeOutBack.transform((t - 0.4) / 0.6));
        return Transform.scale(scale: scale, child: child);
      },
      child: body,
    );
  }
}
