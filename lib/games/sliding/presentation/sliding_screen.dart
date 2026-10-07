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
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';
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
  int? _points;
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
      _points = null;
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

  int _inPlaceCount() => _inPlaceSet().length;

  /// Cac so dang nam dung cho.
  Set<int> _inPlaceSet() => {
    for (var i = 0; i < _game.tiles.length - 1; i++)
      if (_game.tiles[i] == i + 1) i + 1,
  };

  /// Thong bao noi "Dung cho!" khi vua co so ve dung vi tri.
  int _toastId = 0;
  List<int> _toastValues = const [];

  void _announcePlaced(Set<int> before) {
    final fresh = _inPlaceSet().difference(before).toList()..sort();
    if (fresh.isEmpty || _reduceMotion) return;
    setState(() {
      _toastId++;
      _toastValues = fresh;
    });
  }

  void _afterMove(Set<int> placedBefore) {
    GameFx.tap();
    Sfx.play(SfxKind.tap);
    _hintTile = null;
    if (_game.solved) {
      _onWin();
      return;
    }
    if (_inPlaceSet().difference(placedBefore).isNotEmpty) {
      Sfx.play(SfxKind.place);
      GameFx.success();
      _announcePlaced(placedBefore);
    }
    _save();
  }

  void _tap(int i) {
    if (_locked) return;
    final before = _inPlaceSet();
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
    final before = _inPlaceSet();
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
    if (_points == null) {
      final pts = Scoring.points(
        base: 1000,
        seconds: sec,
        parSeconds: switch (n) {
          3 => 90,
          4 => 240,
          _ => 600,
        },
        mult: switch (n) {
          3 => 0.6,
          4 => 1.0,
          _ => 2.0,
        },
        hints: _maxHints - _hintsLeft,
      );
      _points = pts;
      await _store.awardPoints(_id, pts);
    }
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
      backgroundColor: Candy.bgTop,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void both(VoidCallback f) {
            setState(f);
            setSheet(() {});
            _savePrefs();
            _save();
          }

          const head = TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          );
          return SafeArea(
            child: Theme(
              data: ThemeData.dark(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.daily == null) ...[
                      const Text('Kích thước', style: head),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final (i, n) in const [3, 4, 5].indexed) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(
                              child: CandyButton(
                                dim: n != _size,
                                onPressed: () {
                                  if (n == _size) return;
                                  Navigator.of(ctx).pop();
                                  _newGame(size: n);
                                },
                                child: Text('${n}x$n'),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text('Chế độ', style: head),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CandyButton(
                            colors: Candy.green,
                            dim: _imageMode,
                            onPressed: () => both(() => _imageMode = false),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pin_outlined),
                                SizedBox(width: 6),
                                Text('Số'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CandyButton(
                            colors: Candy.orange,
                            dim: !_imageMode,
                            onPressed: () => both(() => _imageMode = true),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.image_outlined),
                                SizedBox(width: 6),
                                Text('Ảnh'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_imageMode) ...[
                      const SizedBox(height: 16),
                      const Text('Tranh', style: head),
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
                                        ? Candy.gold
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
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _game.size;
    final bestMoves = _store.stats('$_id.$n').best;
    final bestTime = _store.stats('$_id.$n.t').best;
    return CandyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          leading: BackButton(onPressed: () => context.go(_store.homeRoute)),
          title: Text(
            _won
                ? 'Xếp số ${n}x$n - Thắng!'
                : 'Xếp số ${n}x$n${widget.daily != null ? ' · Hôm nay' : ''}',
          ),
          actions: [
            const ScoreChip(),
            const HelpAction(gameId: 'sliding'),
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
                      GlassBar(
                        children: [
                          _Stat(
                            icon: Icons.touch_app_outlined,
                            colors: Candy.orange,
                            label: 'Lượt',
                            value: '${_game.moves}',
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: _tick,
                            builder: (_, _, _) => _Stat(
                              icon: Icons.timer_outlined,
                              colors: Candy.blue,
                              label: 'Giờ',
                              value: _fmtTime(_elapsed),
                            ),
                          ),
                          Flexible(
                            child: _Stat(
                              icon: Icons.emoji_events_outlined,
                              colors: Candy.purple,
                              label: 'Kỷ lục',
                              value: bestMoves == null
                                  ? '-'
                                  : '$bestMoves · ${bestTime == null ? '-' : _fmtTime(bestTime * 1000)}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PlacedBar(
                        count: _shuffling ? 0 : _inPlaceCount(),
                        total: n * n - 1,
                      ),
                      const SizedBox(height: 10),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Shake(
                            key: _shakeKey,
                            child: CandyFrame(padding: 6, child: _buildBoard()),
                          ),
                          if (_toastValues.isNotEmpty)
                            Positioned(
                              top: -14,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: _PlacedToast(
                                  key: ValueKey(_toastId),
                                  values: _toastValues,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildActions(),
                      const SizedBox(height: 8),
                      CandyRibbon(
                        text: _imageMode
                            ? 'Ghép lại bức tranh, ô trống ở góc dưới phải'
                            : 'Xếp số từ 1 đến ${n * n - 1}, ô trống ở góc dưới phải',
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
              points: _points,
              onAgain: _newGame,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    Widget btn(
      IconData icon,
      String tip,
      VoidCallback? onTap,
      List<Color> colors, {
      String? badge,
    }) {
      return Badge(
        isLabelVisible: badge != null,
        label: badge == null ? null : Text(badge),
        child: Tooltip(
          message: tip,
          child: CandyButton(
            colors: colors,
            dim: onTap == null,
            circle: true,
            padding: const EdgeInsets.all(12),
            onPressed: onTap,
            child: Icon(icon, size: 26),
          ),
        ),
      );
    }

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          btn(
            Icons.undo,
            'Hoàn tác',
            (_locked || !_game.canUndo) ? null : _undo,
            Candy.green,
          ),
          btn(
            Icons.lightbulb_outline,
            'Gợi ý',
            _locked ? null : _hint,
            Candy.orange,
            badge: '$_hintsLeft',
          ),
          Listener(
            onPointerDown: (_) {
              if (!_won && !_paused && !_shuffling) {
                setState(() => _peek = true);
              }
            },
            onPointerUp: (_) => setState(() => _peek = false),
            onPointerCancel: (_) => setState(() => _peek = false),
            child: Tooltip(
              message: 'Giữ để xem bản gốc',
              child: CandyButton(
                colors: Candy.purple,
                circle: true,
                padding: const EdgeInsets.all(12),
                onPressed: () {},
                child: const Icon(Icons.visibility_outlined, size: 26),
              ),
            ),
          ),
          btn(
            _paused ? Icons.play_arrow : Icons.pause,
            _paused ? 'Tiếp tục' : 'Tạm dừng',
            (_won || _shuffling) ? null : _togglePause,
            Candy.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
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
                for (var i = 0; i < n * n; i++)
                  Positioned(
                    left: (i % n) * (cell + gap),
                    top: (i ~/ n) * (cell + gap),
                    width: cell,
                    height: cell,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(cell * .14),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.25),
                          width: 2,
                        ),
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
                    child: GestureDetector(
                      onTap: _togglePause,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: GlassStyle.of(context).inner,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pause_circle_outline,
                                size: 56,
                                color: Candy.gold,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tạm dừng',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Chạm để tiếp tục',
                                style: TextStyle(color: Colors.white70),
                              ),
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

/// Vien thuoc kinh (nhu GlassStat) nhung co them nhan nho phia tren gia tri.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.colors,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final List<Color> colors;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final g = GlassStyle.of(context);
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
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
                  Text(
                    value,
                    style: TextStyle(
                      color: g.pillText,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageMode
          ? CustomPaint(painter: ArtPainter(art))
          : ColoredBox(
              color: Candy.bgTop,
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
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: _paletteFor(i, n),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '$i',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Color(0x88000000), blurRadius: 2),
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

/// Mau keo theo vi tri dung cua o (hang + cot), xoay vong.
List<Color> _paletteFor(int value, int n) {
  final r = (value - 1) ~/ n;
  final c = (value - 1) % n;
  const order = [
    Candy.blue,
    Candy.green,
    Candy.orange,
    Candy.purple,
    Candy.pink,
    Candy.teal,
  ];
  return order[(r + c) % order.length];
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

class _TileViewState extends State<_TileView> with TickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  bool _litNow = false;
  Timer? _litTimer;

  @override
  void didUpdateWidget(_TileView old) {
    super.didUpdateWidget(old);
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!old.inPlace && widget.inPlace && !widget.won && !reduce) {
      _bounce.forward(from: 0);
      _burst.forward(from: 0);
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
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final v = widget.value;
    final fast = MediaQuery.disableAnimationsOf(context);
    final dur = fast ? Duration.zero : const Duration(milliseconds: 260);
    final home = widget.inPlace;
    final img = widget.imageMode;
    final colors = _litNow
        ? const [Color(0xFFFFE680), Color(0xFFE09A00)]
        : _paletteFor(v, widget.n);
    final radius = BorderRadius.circular(widget.cell * .14);
    final borderColor = widget.hinted
        ? s.error
        : img
        ? (home ? s.tertiary : Colors.transparent)
        : (home ? Colors.white : Candy.gold);
    final text = Text(
      '$v',
      style: TextStyle(
        fontSize: widget.cell * .42,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        shadows: img
            ? const [Shadow(blurRadius: 4, color: Colors.black54)]
            : const [
                Shadow(
                  color: Color(0xAA000000),
                  blurRadius: 3,
                  offset: Offset(0, 1.5),
                ),
              ],
      ),
    );
    final tile = AnimatedBuilder(
      animation: _bounce,
      builder: (_, child) => Transform.scale(
        scale: 1 + .13 * sin(pi * _bounce.value),
        child: child,
      ),
      child: Semantics(
        label: 'Ô $v',
        child: _Press(
          child: AnimatedContainer(
            duration: dur,
            decoration: BoxDecoration(
              gradient: img
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: colors,
                    ),
              borderRadius: radius,
              border: Border.all(
                width: widget.hinted ? 4 : 2,
                color: borderColor,
              ),
              boxShadow: img
                  ? null
                  : [
                      BoxShadow(
                        color: Candy.deep(colors),
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (img)
                    CustomPaint(
                      painter: ArtTilePainter(
                        art: widget.art,
                        row: (v - 1) ~/ widget.n,
                        col: (v - 1) % widget.n,
                        n: widget.n,
                      ),
                    ),
                  if (img)
                    AnimatedContainer(
                      duration: dur,
                      color: _litNow
                          ? Colors.white.withValues(alpha: .45)
                          : Colors.transparent,
                    ),
                  if (!img) CandyGloss(radius: widget.cell * .1),
                  if (widget.showNum) Center(child: text),
                  if (home && !widget.won)
                    Positioned(
                      top: widget.cell * .05,
                      right: widget.cell * .05,
                      child: Container(
                        width: widget.cell * .26,
                        height: widget.cell * .26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2EC27E),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: widget.cell * .2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: tile),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _burst,
              builder: (_, _) => CustomPaint(
                painter: _BurstPainter(_burst.value, widget.cell),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Vong sang xanh + tia sao toa ra khi mot o ve dung cho.
class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.t, this.cell);

  final double t;
  final double cell;

  static const _colors = [
    Color(0xFFFFEB3B),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFFF80AB),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final e = Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      cell * (.45 + .55 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * fade + 1
        ..color = const Color(0xFF2EC27E).withValues(alpha: fade),
    );
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + .3;
      final r = cell * (.4 + .75 * e);
      final p = c + Offset(cos(a), sin(a)) * r;
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: fade);
      final star = Path();
      final k = cell * .09 * (1 - t * .5);
      for (var j = 0; j < 8; j++) {
        final rad = j.isEven ? k * 1.6 : k * .6;
        final b = -pi / 2 + j * pi / 4;
        final pt = p + Offset(cos(b), sin(b)) * rad;
        j == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(star..close(), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// Thanh tien do: bao nhieu o da ve dung cho.
class _PlacedBar extends StatelessWidget {
  const _PlacedBar({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final f = total == 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return Semantics(
      label: 'Đúng chỗ $count trên $total',
      excludeSemantics: true,
      child: Container(
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.22),
          border: Border.all(
            color: GlassStyle.of(context).outerBorder,
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  widthFactor: f.clamp(0.02, 1.0),
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: count == total && total > 0
                            ? Candy.orange
                            : Candy.green,
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Đúng chỗ $count/$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    shadows: [Shadow(color: Color(0xAA000000), blurRadius: 2)],
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

/// Bong bong thong bao noi len khi co so ve dung cho.
class _PlacedToast extends StatelessWidget {
  const _PlacedToast({required this.values, super.key});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final label = values.length == 1
        ? 'Số ${values.first} đúng chỗ!'
        : 'Số ${values.join(', ')} đúng chỗ!';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (_, k, child) {
        final up = Curves.easeOutCubic.transform((k * 2).clamp(0.0, 1.0));
        final opacity = k < .7 ? 1.0 : (1 - (k - .7) / .3).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 10 - 26 * up),
            child: Transform.scale(
              scale: .6 + .4 * Curves.easeOutBack.transform(up),
              child: child,
            ),
          ),
        );
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: Candy.green,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nhun xuong nhe khi cham vao o (phan hoi bam).
class _Press extends StatefulWidget {
  const _Press({required this.child});

  final Widget child;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}
