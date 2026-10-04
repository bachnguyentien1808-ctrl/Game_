import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
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
      Sfx.play(SfxKind.win);
      _confetti = true;
    }
    _save();
    if (_g.isOver && !out.justWon) Sfx.play(SfxKind.error);
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final n in const [3, 4, 5])
              ListTile(
                key: ValueKey('size$n'),
                leading: Icon(
                  n == _g.size
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text('$n x $n'),
                subtitle: Text(
                  'Kỷ lục ${_store.stats(statIdFor(n)).best ?? 0} - đích ${Game2048.targetFor(n)}',
                ),
                onTap: () => Navigator.pop(ctx, n),
              ),
          ],
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
    final s = Theme.of(context).colorScheme;
    final won = _g.won && !_g.continued;
    final over = _g.isOver;
    final best = max(_store.stats(statIdFor(_g.size)).best ?? 0, _g.score);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text('2048  ${_g.size}x${_g.size}'),
        actions: [
          Badge.count(
            count: _g.undosLeft,
            child: IconButton(
              key: const ValueKey('undo'),
              tooltip: 'Hoàn tác (còn ${_g.undosLeft})',
              icon: const Icon(Icons.undo),
              onPressed: _g.canUndo ? _undo : null,
            ),
          ),
          IconButton(
            key: const ValueKey('size'),
            tooltip: 'Kích thước',
            icon: const Icon(Icons.grid_view),
            onPressed: _pickSize,
          ),
          IconButton(
            key: const ValueKey('restart'),
            tooltip: 'Ván mới',
            icon: const Icon(Icons.refresh),
            onPressed: _askNewGame,
          ),
        ],
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
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _ScoreBox(
                                label: 'Điểm',
                                value: _g.score,
                                animate: _animate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ScoreBox(
                                label: 'Cao nhất',
                                value: best,
                                animate: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: _board(s, won, over),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Vuốt hoặc dùng mũi tên / WASD. Đích: ${_g.target}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: Confetti(show: _confetti)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _board(ColorScheme s, bool won, bool over) {
    const gap = 8.0;
    final n = _g.size;
    final dur = Duration(milliseconds: _animate ? _slideMs : 0);
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth;
        final cell = (side - gap * (n + 1)) / n;
        double pos(int i) => gap + i * (cell + gap);
        final sorted = [..._tiles]
          ..sort((a, b) => (b.dying ? 1 : 0) - (a.dying ? 1 : 0));
        return Container(
          decoration: BoxDecoration(
            color: s.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
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
                        color: s.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
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
                                fontWeight: FontWeight.w800,
                                color: s.primary,
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
    super.key,
  });

  final String title;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.label,
    required this.value,
    required this.animate,
  });

  final String label;
  final int value;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            TweenAnimationBuilder<int>(
              tween: IntTween(end: value),
              duration: Duration(milliseconds: animate ? 300 : 0),
              builder: (_, v, _) =>
                  Text('$v', style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mau o theo gia tri (sang/toi).
(Color, Color) tileColors(int v, ColorScheme s) {
  final dark = s.brightness == Brightness.dark;
  if (v <= 4) {
    return v == 2
        ? (s.surfaceContainerHighest, s.onSurface)
        : (s.secondaryContainer, s.onSecondaryContainer);
  }
  final k = (log(v) / ln2).round().clamp(3, 14);
  // 8 cam -> 16 cam dam -> 32 do cam -> 64 do -> 128.. vang -> ... xanh tim.
  const hues = <double>[28, 20, 12, 2, 48, 46, 44, 42, 40, 200, 260, 290];
  final h = hues[(k - 3).clamp(0, hues.length - 1)];
  final hsl = HSLColor.fromAHSL(1, h, dark ? 0.62 : 0.78, dark ? 0.42 : 0.55);
  return (hsl.toColor(), Colors.white);
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
    final s = Theme.of(context).colorScheme;
    final (bg, fg) = tileColors(value, s);
    final digits = '$value'.length;
    final font =
        cell *
        switch (digits) {
          <= 2 => 0.5,
          3 => 0.4,
          4 => 0.32,
          _ => 0.26,
        };
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: FittedBox(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: font,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
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
