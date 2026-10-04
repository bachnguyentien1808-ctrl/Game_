import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/games/sliding/domain/sliding_engine.dart';
import 'package:puzzle_hub/games/sliding/presentation/sliding_art.dart';

const _id = 'sliding';
const _prefsKey = 'sliding.prefs';
const _maxHints = 3;

String _fmtTime(int ms) {
  final s = ms ~/ 1000;
  final m = s ~/ 60;
  return '$m:${(s % 60).toString().padLeft(2, '0')}';
}

class SlidingScreen extends ConsumerStatefulWidget {
  const SlidingScreen({super.key, this.daily});

  /// Khoa ngay yyyyMMdd khi o che do thu thach ngay (luon 4x4).
  final String? daily;

  @override
  ConsumerState<SlidingScreen> createState() => _SlidingScreenState();
}

class _SlidingScreenState extends ConsumerState<SlidingScreen>
    with WidgetsBindingObserver {
  late final ProgressStore _raw = ref.read(progressStoreProvider);
  late final GameStore _store = GameStore(_raw, daily: widget.daily);
  final _shakeKey = GlobalKey<ShakeState>();

  late SlidingPuzzle _game;
  int _size = 4;
  bool _imageMode = false;
  int _art = 0;
  bool _showNums = true;

  final Stopwatch _sw = Stopwatch();
  int _baseMs = 0;
  Timer? _timer;
  final ValueNotifier<int> _tick = ValueNotifier(0);

  bool _paused = false;
  bool _won = false;
  bool _banner = false;
  bool _shuffling = false;
  bool _peek = false;
  List<int>? _display;
  int _hintsLeft = _maxHints;
  int? _hintTile;
  String _resultText = '';
  Offset _pan = Offset.zero;
  bool _panFired = false;
  int _gen = 0;

  int get _elapsed => _baseMs + _sw.elapsedMilliseconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    final saved = _store.loadState(_id);
    SlidingPuzzle? restored;
    if (saved != null) {
      try {
        restored = SlidingPuzzle.fromJson(saved);
        if (widget.daily != null && restored.size != 4) restored = null;
        if (restored != null) {
          _size = restored.size;
          _imageMode = saved['mode'] == 'img';
          _art = (saved['art'] as int? ?? 0) % SlidingArt.count;
          _showNums = saved['nums'] as bool? ?? true;
          _baseMs = saved['ms'] as int? ?? 0;
          _hintsLeft = (saved['hints'] as int? ?? _maxHints).clamp(
            0,
            _maxHints,
          );
        }
      } on Object {
        restored = null;
      }
    }
    if (restored != null && !restored.solved) {
      _game = restored;
      _startClock();
    } else {
      _baseMs = 0;
      _hintsLeft = _maxHints;
      _game = SlidingPuzzle.generate(size: _size, rng: _store.rngFor(_id));
      _store.recordStart(_id);
      _raw.recordStart('$_id.$_size');
      _save();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playShuffle();
      });
      _shuffling = true;
      _display = _solvedTiles(_size);
    }
  }

  void _loadPrefs() {
    final p = _raw.loadState(_prefsKey);
    if (p == null) return;
    try {
      if (widget.daily == null) {
        final sz = p['size'] as int? ?? 4;
        if (sz >= 3 && sz <= 5) _size = sz;
      }
      _imageMode = p['mode'] == 'img';
      _art = (p['art'] as int? ?? 0) % SlidingArt.count;
      _showNums = p['nums'] as bool? ?? true;
    } on Object {
      // bo qua tuy chon hong
    }
  }

  void _savePrefs() {
    _raw.saveState(_prefsKey, {
      'size': _size,
      'mode': _imageMode ? 'img' : 'num',
      'art': _art,
      'nums': _showNums,
    });
  }

  static List<int> _solvedTiles(int n) => [
    for (var i = 1; i < n * n; i++) i,
    0,
  ];

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _tick.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _clockRunning) {
      setState(_pauseClock);
      _save();
    }
  }

  bool get _clockRunning => _sw.isRunning;

  void _startClock() {
    if (_won || _paused || _shuffling) return;
    _sw.start();
    _timer ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_sw.isRunning) _tick.value++;
    });
  }

  void _pauseClock() {
    _sw.stop();
    _paused = true;
  }

  void _stopClock() {
    _sw.stop();
    _timer?.cancel();
    _timer = null;
  }

  void _save() {
    if (_won) return;
    _store.saveState(_id, {
      ..._game.toJson(),
      'mode': _imageMode ? 'img' : 'num',
      'art': _art,
      'nums': _showNums,
      'ms': _elapsed,
      'hints': _hintsLeft,
    });
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// Xao tron ban dau: o bay tu vi tri da giai ve vi tri tron.
  void _playShuffle() {
    final gen = ++_gen;
    if (_reduceMotion) {
      setState(() {
        _display = null;
        _shuffling = false;
      });
      _startClock();
      return;
    }
    setState(() => _display = null);
    Sfx.play(SfxKind.flip);
    final total = 520 + _size * _size * 22 + 120;
    Future<void>.delayed(Duration(milliseconds: total), () {
      if (!mounted || gen != _gen) return;
      setState(() => _shuffling = false);
      _startClock();
    });
  }

  void _newGame({int? size}) {
    _stopClock();
    _gen++;
    final n = widget.daily != null ? 4 : (size ?? _size);
    setState(() {
      _size = n;
      _won = false;
      _banner = false;
      _paused = false;
      _peek = false;
      _hintTile = null;
      _hintsLeft = _maxHints;
      _baseMs = 0;
      _sw.reset();
      _game = SlidingPuzzle.generate(size: n, rng: _store.rngFor(_id));
      _shuffling = true;
      _display = _solvedTiles(n);
    });
    _store.recordStart(_id);
    _raw.recordStart('$_id.$n');
    _savePrefs();
    _save();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playShuffle();
    });
  }

  bool get _locked => _paused || _won || _shuffling;

  int _inPlaceCount() {
    var k = 0;
    for (var i = 0; i < _game.tiles.length - 1; i++) {
      if (_game.tiles[i] == i + 1) k++;
    }
    return k;
  }

  void _afterMove(int placedBefore) {
    GameFx.tap();
    Sfx.play(SfxKind.tap);
    _hintTile = null;
    if (_game.solved) {
      _onWin();
      return;
    }
    if (_inPlaceCount() > placedBefore) Sfx.play(SfxKind.place);
    _save();
  }

  void _tap(int i) {
    if (_locked) return;
    final before = _inPlaceCount();
    var moved = false;
    setState(() => moved = _game.tap(i));
    if (!moved) {
      GameFx.error();
      Sfx.play(SfxKind.error);
      _shakeKey.currentState?.shake();
      return;
    }
    _afterMove(before);
  }

  void _swipe(SlideDir d) {
    if (_locked) return;
    final before = _inPlaceCount();
    var moved = false;
    setState(() => moved = _game.slide(d));
    if (moved) _afterMove(before);
  }

  void _undo() {
    if (_locked || !_game.canUndo) return;
    setState(() {
      _game.undo();
      _hintTile = null;
    });
    GameFx.tap();
    Sfx.play(SfxKind.erase);
    _save();
  }

  void _hint() {
    if (_locked) return;
    if (_hintsLeft <= 0) {
      GameFx.error();
      return;
    }
    final h = _game.hint();
    if (h == null) return;
    setState(() {
      _hintsLeft--;
      _hintTile = h;
    });
    GameFx.tap();
    _save();
  }

  void _togglePause() {
    if (_won || _shuffling) return;
    setState(() {
      if (_paused) {
        _paused = false;
        _startClock();
      } else {
        _pauseClock();
      }
    });
    _save();
  }

  Future<void> _onWin() async {
    _stopClock();
    final ms = _elapsed;
    final moves = _game.moves;
    final n = _game.size;
    final sec = max(1, ms ~/ 1000);
    final oldMoves = _store.stats('$_id.$n').best;
    final oldTime = _store.stats('$_id.$n.t').best;
    final newMoves = oldMoves == null || moves < oldMoves;
    final newTime = oldTime == null || sec < oldTime;
    setState(() {
      _won = true;
      _hintTile = null;
      _peek = false;
      _paused = false;
      _resultText =
          '$moves lượt · ${_fmtTime(ms)}\n'
          'Kỷ lục ${n}x$n: ${min(moves, oldMoves ?? moves)} lượt · '
          '${_fmtTime(min(sec, oldTime ?? sec) * 1000)}'
          '${widget.daily == null && (newMoves || newTime) ? '\nKỷ lục mới!' : ''}';
    });
    GameFx.success();
    Sfx.play(SfxKind.win);
    if (widget.daily != null) {
      await _store.recordWin(_id, score: moves);
    } else {
      await _raw.recordWin(
        _id,
        score: n == 4 ? moves : null,
        lowerIsBetter: true,
      );
      await _raw.recordWin('$_id.$n', score: moves, lowerIsBetter: true);
      await _raw.recordScore('$_id.$n.t', sec, lowerIsBetter: true);
    }
    await _store.clearState(_id);
    final sweep = _reduceMotion ? 0 : 140 * n * n ~/ 2 + 500;
    Future<void>.delayed(Duration(milliseconds: sweep), () {
      if (mounted) setState(() => _banner = true);
    });
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void both(VoidCallback f) {
            setState(f);
            setSheet(() {});
            _savePrefs();
            _save();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.daily == null) ...[
                    Text(
                      'Kích thước',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 3, label: Text('3x3')),
                          ButtonSegment(value: 4, label: Text('4x4')),
                          ButtonSegment(value: 5, label: Text('5x5')),
                        ],
                        selected: {_size},
                        onSelectionChanged: (v) {
                          if (v.first == _size) return;
                          Navigator.of(ctx).pop();
                          _newGame(size: v.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('Chế độ', style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.pin_outlined),
                          label: Text('Số'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.image_outlined),
                          label: Text('Ảnh'),
                        ),
                      ],
                      selected: {_imageMode},
                      onSelectionChanged: (v) =>
                          both(() => _imageMode = v.first),
                    ),
                  ),
                  if (_imageMode) ...[
                    const SizedBox(height: 16),
                    Text('Tranh', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: SlidingArt.count,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => Semantics(
                          label: SlidingArt.names[i],
                          selected: i == _art,
                          button: true,
                          child: GestureDetector(
                            onTap: () => both(() => _art = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  width: 3,
                                  color: i == _art
                                      ? Theme.of(ctx).colorScheme.primary
                                      : Colors.transparent,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: CustomPaint(painter: ArtPainter(i)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hiện số trên ô'),
                      value: _showNums,
                      onChanged: (v) => both(() => _showNums = v),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final n = _game.size;
    final bestMoves = _store.stats('$_id.$n').best;
    final bestTime = _store.stats('$_id.$n.t').best;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(_store.homeRoute)),
        title: Text(
          _won
              ? 'Xếp số ${n}x$n - Thắng!'
              : 'Xếp số ${n}x$n${widget.daily != null ? ' · Hôm nay' : ''}',
        ),
        actions: [
          IconButton(
            tooltip: widget.daily != null ? 'Chơi lại cùng đề' : 'Ván mới',
            icon: const Icon(Icons.refresh),
            onPressed: _shuffling ? null : _newGame,
          ),
          IconButton(
            tooltip: 'Tuỳ chọn',
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Stat(
                          icon: Icons.touch_app_outlined,
                          label: 'Lượt',
                          value: '${_game.moves}',
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _tick,
                          builder: (_, _, _) => _Stat(
                            icon: Icons.timer_outlined,
                            label: 'Giờ',
                            value: _fmtTime(_elapsed),
                          ),
                        ),
                        _Stat(
                          icon: Icons.emoji_events_outlined,
                          label: 'Kỷ lục',
                          value: bestMoves == null
                              ? '-'
                              : '$bestMoves · ${bestTime == null ? '-' : _fmtTime(bestTime * 1000)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Shake(key: _shakeKey, child: _buildBoard(s)),
                    const SizedBox(height: 16),
                    _buildActions(s),
                    const SizedBox(height: 8),
                    Text(
                      _imageMode
                          ? 'Ghép lại bức tranh, ô trống ở góc dưới phải'
                          : 'Xếp số từ 1 đến ${n * n - 1}, ô trống ở góc dưới phải',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          WinBanner(
            show: _banner,
            title: 'Hoàn thành!',
            subtitle: _resultText,
            onAgain: _newGame,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ColorScheme s) {
    Widget btn(
      IconData icon,
      String tip,
      VoidCallback? onTap, {
      String? badge,
    }) {
      return Badge(
        isLabelVisible: badge != null,
        label: badge == null ? null : Text(badge),
        child: IconButton.filledTonal(
          tooltip: tip,
          icon: Icon(icon),
          onPressed: onTap,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        btn(Icons.undo, 'Hoàn tác', (_locked || !_game.canUndo) ? null : _undo),
        btn(
          Icons.lightbulb_outline,
          'Gợi ý',
          _locked ? null : _hint,
          badge: '$_hintsLeft',
        ),
        Listener(
          onPointerDown: (_) {
            if (!_won && !_paused && !_shuffling) setState(() => _peek = true);
          },
          onPointerUp: (_) => setState(() => _peek = false),
          onPointerCancel: (_) => setState(() => _peek = false),
          child: IconButton.filledTonal(
            tooltip: 'Giữ để xem bản gốc',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () {},
          ),
        ),
        btn(
          _paused ? Icons.play_arrow : Icons.pause,
          _paused ? 'Tiếp tục' : 'Tạm dừng',
          (_won || _shuffling) ? null : _togglePause,
        ),
      ],
    );
  }

  Widget _buildBoard(ColorScheme s) {
    final n = _game.size;
    const gap = 6.0;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.maxWidth;
          final cell = (side - gap * (n - 1)) / n;
          final tiles = _display ?? _game.tiles;
          final fast = _reduceMotion;
          final tileDur = fast
              ? Duration.zero
              : (_shuffling
                    ? null // theo tung o
                    : const Duration(milliseconds: 150));
          final sweepMs = 140 * n * n ~/ 2;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final col = (d.localPosition.dx / (cell + gap)).floor();
              final row = (d.localPosition.dy / (cell + gap)).floor();
              if (col < 0 || col >= n || row < 0 || row >= n) return;
              _tap(row * n + col);
            },
            onPanStart: (_) {
              _pan = Offset.zero;
              _panFired = false;
            },
            onPanUpdate: (d) {
              if (_panFired) return;
              _pan += d.delta;
              if (_pan.distance < 16) return;
              _panFired = true;
              if (_pan.dx.abs() > _pan.dy.abs()) {
                _swipe(_pan.dx > 0 ? SlideDir.right : SlideDir.left);
              } else {
                _swipe(_pan.dy > 0 ? SlideDir.down : SlideDir.up);
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: s.surfaceContainerHighest.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                for (var i = 0; i < tiles.length; i++)
                  if (tiles[i] != 0)
                    AnimatedPositioned(
                      key: ValueKey('t${tiles[i]}'),
                      duration:
                          tileDur ??
                          Duration(milliseconds: 520 + tiles[i] * 22),
                      curve: _shuffling
                          ? Curves.easeInOutCubic
                          : Curves.easeOutCubic,
                      left: (i % n) * (cell + gap),
                      top: (i ~/ n) * (cell + gap),
                      width: cell,
                      height: cell,
                      child: _TileView(
                        value: tiles[i],
                        n: n,
                        cell: cell,
                        imageMode: _imageMode,
                        art: _art,
                        showNum: !_imageMode || _showNums,
                        inPlace: !_shuffling && tiles[i] == i + 1,
                        lit: _won,
                        litDelay: Duration(
                          milliseconds: fast
                              ? 0
                              : (tiles[i] - 1) * sweepMs ~/ (n * n),
                        ),
                        hinted: _hintTile == i,
                        won: _won,
                      ),
                    ),
                if (_won && _imageMode)
                  Positioned(
                    left: (n - 1) * (cell + gap),
                    top: (n - 1) * (cell + gap),
                    width: cell,
                    height: cell,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(
                        milliseconds: fast ? 0 : 140 * n * n ~/ 2,
                      ),
                      builder: (_, v, child) =>
                          Opacity(opacity: v, child: child),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CustomPaint(
                          painter: ArtTilePainter(
                            art: _art,
                            row: n - 1,
                            col: n - 1,
                            n: n,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_peek)
                  Positioned.fill(
                    child: _SolvedPreview(
                      imageMode: _imageMode,
                      art: _art,
                      n: n,
                    ),
                  ),
                if (_paused)
                  Positioned.fill(
                    child: Material(
                      color: s.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _togglePause,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pause_circle_outline,
                                size: 56,
                                color: s.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tạm dừng',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Text('Chạm để tiếp tục'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: s.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SolvedPreview extends StatelessWidget {
  const _SolvedPreview({
    required this.imageMode,
    required this.art,
    required this.n,
  });

  final bool imageMode;
  final int art;
  final int n;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageMode
          ? CustomPaint(painter: ArtPainter(art))
          : ColoredBox(
              color: s.surface,
              child: GridView.count(
                crossAxisCount: n,
                padding: const EdgeInsets.all(6),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 1; i < n * n; i++)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: s.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '$i',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: s.onTertiaryContainer,
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

/// Mot o: doi mau + nay nhe khi ve dung cho, sang len khi thang.
class _TileView extends StatefulWidget {
  const _TileView({
    required this.value,
    required this.n,
    required this.cell,
    required this.imageMode,
    required this.art,
    required this.showNum,
    required this.inPlace,
    required this.lit,
    required this.litDelay,
    required this.hinted,
    required this.won,
  });

  final int value;
  final int n;
  final double cell;
  final bool imageMode;
  final int art;
  final bool showNum;
  final bool inPlace;
  final bool lit;
  final Duration litDelay;
  final bool hinted;
  final bool won;

  @override
  State<_TileView> createState() => _TileViewState();
}

class _TileViewState extends State<_TileView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  bool _litNow = false;
  Timer? _litTimer;

  @override
  void didUpdateWidget(_TileView old) {
    super.didUpdateWidget(old);
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!old.inPlace && widget.inPlace && !widget.won && !reduce) {
      _bounce.forward(from: 0);
    }
    if (widget.lit && !old.lit) {
      if (widget.litDelay == Duration.zero) {
        _litNow = true;
      } else {
        _litTimer = Timer(widget.litDelay, () {
          if (!mounted) return;
          setState(() => _litNow = true);
          if (!MediaQuery.disableAnimationsOf(context)) {
            _bounce.forward(from: 0);
          }
        });
      }
    }
    if (!widget.lit && old.lit) {
      _litTimer?.cancel();
      _litNow = false;
    }
  }

  @override
  void dispose() {
    _litTimer?.cancel();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final v = widget.value;
    final fast = MediaQuery.disableAnimationsOf(context);
    final dur = fast ? Duration.zero : const Duration(milliseconds: 260);
    final home = widget.inPlace;
    final bg = _litNow
        ? s.primary
        : home
        ? s.tertiaryContainer
        : s.primaryContainer;
    final fg = _litNow
        ? s.onPrimary
        : home
        ? s.onTertiaryContainer
        : s.onPrimaryContainer;
    final radius = BorderRadius.circular(widget.cell * .14);
    final borderColor = widget.hinted
        ? s.error
        : (widget.imageMode && home ? s.tertiary : Colors.transparent);
    final text = Text(
      '$v',
      style: TextStyle(
        fontSize: widget.cell * .42,
        fontWeight: FontWeight.w800,
        color: widget.imageMode ? Colors.white : fg,
        shadows: widget.imageMode
            ? const [Shadow(blurRadius: 4, color: Colors.black54)]
            : null,
      ),
    );
    return AnimatedBuilder(
      animation: _bounce,
      builder: (_, child) => Transform.scale(
        scale: 1 + .13 * sin(pi * _bounce.value),
        child: child,
      ),
      child: Semantics(
        label: 'Ô $v',
        child: AnimatedContainer(
          duration: dur,
          decoration: BoxDecoration(
            color: widget.imageMode ? null : bg,
            borderRadius: radius,
            border: Border.all(
              width: widget.hinted ? 4 : 2,
              color: borderColor,
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.imageMode)
                  CustomPaint(
                    painter: ArtTilePainter(
                      art: widget.art,
                      row: (v - 1) ~/ widget.n,
                      col: (v - 1) % widget.n,
                      n: widget.n,
                    ),
                  ),
                if (widget.imageMode)
                  AnimatedContainer(
                    duration: dur,
                    color: _litNow
                        ? Colors.white.withValues(alpha: .45)
                        : Colors.transparent,
                  ),
                if (widget.showNum) Center(child: text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
