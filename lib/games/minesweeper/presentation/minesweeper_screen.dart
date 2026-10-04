import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/games/minesweeper/domain/minesweeper_engine.dart';

const _id = 'minesweeper';
const _prefsId = 'minesweeper.prefs';
const _maxHints = 3;
const _minCell = 32.0;

typedef _Custom = ({int rows, int cols, int mines});

class MinesweeperScreen extends ConsumerStatefulWidget {
  const MinesweeperScreen({super.key, this.daily});

  /// Khoa ngay yyyyMMdd khi choi o che do thu thach ngay.
  final String? daily;

  @override
  ConsumerState<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class _MinesweeperScreenState extends ConsumerState<MinesweeperScreen>
    with WidgetsBindingObserver {
  late final GameStore _store = GameStore(
    ref.read(progressStoreProvider),
    daily: widget.daily,
  );
  late Minesweeper _game;
  MineLevel _level = MineLevel.easy;
  _Custom _custom = (rows: 12, cols: 12, mines: 25);
  int _seconds = 0;
  int _hintsUsed = 0;
  bool _moved = false;
  bool _flagMode = false;
  bool _resumed = true;
  int _gen = 0;
  int? _hint;
  final Map<int, Duration> _delays = {};
  final _shake = GlobalKey<ShakeState>();
  Timer? _timer;
  Timer? _hintTimer;

  bool get _daily => _store.isDaily;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_daily) _loadPrefs();
    final saved = _store.loadState(_id);
    Minesweeper? restored;
    if (saved != null) {
      try {
        final g = Minesweeper.fromJson(saved);
        if (g.rows >= 1 && g.cols >= 1 && !g.over) {
          restored = g;
          _seconds = saved['seconds'] as int? ?? 0;
          _moved = saved['moved'] as bool? ?? g.placed;
          _hintsUsed = saved['hints'] as int? ?? 0;
          _level = _daily
              ? MineLevel.medium
              : MineLevel.byKey(saved['level'] as String?);
        }
      } on Object {
        restored = null;
      }
    }
    if (restored != null) {
      _game = restored;
    } else {
      _newGame(level: _level, silent: true);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_moved || _game.over || !_resumed) return;
      setState(() => _seconds++);
      if (_seconds % 5 == 0) _save();
    });
  }

  void _loadPrefs() {
    final p = _store.loadState(_prefsId);
    if (p == null) return;
    try {
      _level = MineLevel.byKey(p['level'] as String?);
      final c = (
        rows: p['rows'] as int,
        cols: p['cols'] as int,
        mines: p['mines'] as int,
      );
      if (Minesweeper.validateConfig(c.rows, c.cols, c.mines) == null) {
        _custom = c;
      }
    } on Object {
      // Bo qua cau hinh hong, dung mac dinh.
    }
  }

  void _savePrefs() {
    if (_daily) return;
    _store.saveState(_prefsId, {
      'level': _level.key,
      'rows': _custom.rows,
      'cols': _custom.cols,
      'mines': _custom.mines,
    });
  }

  void _newGame({MineLevel? level, bool silent = false}) {
    _gen++;
    _delays.clear();
    _hint = null;
    _seconds = 0;
    _hintsUsed = 0;
    _moved = false;
    if (_daily) {
      _level = MineLevel.medium;
      _game = Minesweeper.daily(rng: _store.rngFor(_id)!);
    } else {
      _level = level ?? _level;
      _game = _level == MineLevel.custom
          ? Minesweeper(
              rows: _custom.rows,
              cols: _custom.cols,
              mines: _custom.mines,
            )
          : Minesweeper(
              rows: _level.rows,
              cols: _level.cols,
              mines: _level.mines,
            );
    }
    if (!silent) Sfx.play(SfxKind.tap);
    _savePrefs();
    _save();
  }

  void _save() => _store.saveState(_id, {
    ..._game.toJson(),
    'seconds': _seconds,
    'moved': _moved,
    'hints': _hintsUsed,
    'level': _level.key,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (!_resumed && !_game.over) _save();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  bool get _reduce => MediaQuery.disableAnimationsOf(context);

  void _act(int r, int c, {required bool flag}) {
    if (_game.over) return;
    final cell = _game.cells[r][c];
    var opened = const <(int, int)>[];
    var flagged = false;
    final wasOpen = cell.open;
    setState(() {
      _delays.clear();
      _hint = null;
      if (wasOpen) {
        opened = _game.chord(r, c);
      } else if (flag) {
        _game.toggleFlag(r, c);
        flagged = true;
      } else {
        opened = _game.open(r, c, rng: _store.rngFor(_id));
      }
      final acted = flagged || opened.isNotEmpty || _game.lost;
      if (acted && !_moved) {
        _moved = true;
        _store.recordStart(_id);
        if (!_daily) _store.recordStart(_level.statsId);
      }
      if (!_reduce) _scheduleWave(r, c, opened);
      if (_game.lost && !_reduce) _scheduleBlast();
      if (_game.won) _finishWin();
    });
    if (_game.lost) {
      Sfx.play(SfxKind.error);
      GameFx.error();
      _shake.currentState?.shake();
      _store.clearState(_id);
      return;
    }
    if (_game.won) {
      Sfx.play(SfxKind.win);
      GameFx.success();
      _recordWin();
      _store.clearState(_id);
      return;
    }
    if (flagged) {
      Sfx.play(SfxKind.place);
      GameFx.tap();
    } else if (opened.isNotEmpty) {
      Sfx.play(SfxKind.flip);
      GameFx.tap();
    }
    _save();
  }

  /// Dot mo lan song: o cang xa o cham cang mo tre.
  void _scheduleWave(int r, int c, List<(int, int)> opened) {
    for (final p in opened) {
      final d = sqrt(pow(p.$1 - r, 2) + pow(p.$2 - c, 2));
      final ms = min(520, (d * 26).round());
      if (ms > 0) {
        _delays[p.$1 * _game.cols + p.$2] = Duration(milliseconds: ms);
      }
    }
  }

  /// Thua: cac mine con lai no lan luot, gan o trung mine truoc.
  void _scheduleBlast() {
    final boom = _game.boom ?? (0, 0);
    final mines = <(int, int)>[
      for (var r = 0; r < _game.rows; r++)
        for (var c = 0; c < _game.cols; c++)
          if (_game.cells[r][c].mine && !_game.cells[r][c].flag) (r, c),
    ];
    double dist((int, int) p) =>
        sqrt(pow(p.$1 - boom.$1, 2) + pow(p.$2 - boom.$2, 2));
    mines.sort((a, b) => dist(a).compareTo(dist(b)));
    final step = mines.isEmpty ? 0 : min(70, 1400 ~/ mines.length);
    for (var i = 0; i < mines.length; i++) {
      final p = mines[i];
      _delays[p.$1 * _game.cols + p.$2] = Duration(
        milliseconds: i == 0 ? 0 : 200 + i * step,
      );
    }
  }

  /// Thang: tu cam co moi mine, lan luot.
  void _finishWin() {
    final flagged = _game.flagAllMines();
    if (_reduce) return;
    final step = flagged.isEmpty ? 0 : min(40, 800 ~/ flagged.length);
    for (var i = 0; i < flagged.length; i++) {
      final p = flagged[i];
      _delays[p.$1 * _game.cols + p.$2] = Duration(milliseconds: i * step);
    }
  }

  void _recordWin() {
    final secs = _seconds;
    if (_daily) {
      _store.recordWin(_id, score: secs, lowerIsBetter: true);
      return;
    }
    // Ky luc tren the game chung chi nhan muc De; moi muc co thong ke rieng.
    _store.recordWin(
      _id,
      score: _level == MineLevel.easy ? secs : null,
      lowerIsBetter: true,
    );
    if (_level != MineLevel.custom) {
      _store.recordWin(_level.statsId, score: secs, lowerIsBetter: true);
    }
  }

  void _useHint() {
    if (_game.over) return;
    void say(String m) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
    if (_hintsUsed >= _maxHints) {
      say('Hết lượt gợi ý của ván này');
      return;
    }
    final h = _game.safeHint();
    if (h == null) {
      say(
        _game.placed
            ? 'Chưa suy ra được ô nào chắc chắn an toàn'
            : 'Hãy mở một ô trước',
      );
      return;
    }
    Sfx.play(SfxKind.tap);
    setState(() {
      _hint = h.$1 * _game.cols + h.$2;
      _hintsUsed++;
    });
    _save();
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  Future<void> _pickLevel() async {
    final pick = await showModalBottomSheet<(MineLevel, _Custom)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LevelSheet(
        current: _level,
        custom: _custom,
        bestOf: (l) => _store.stats(l.statsId).best,
      ),
    );
    if (pick == null || !mounted) return;
    setState(() {
      _custom = pick.$2;
      _newGame(level: pick.$1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final best = _daily || _level == MineLevel.custom
        ? null
        : _store.stats(_level.statsId).best;
    final face = _game.won
        ? Icons.sentiment_very_satisfied
        : _game.lost
        ? Icons.sentiment_very_dissatisfied
        : Icons.sentiment_satisfied;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(_store.homeRoute)),
        title: Text(
          _game.won
              ? 'Dò mìn - Thắng!'
              : _game.lost
              ? 'Dò mìn - Nổ mìn'
              : 'Dò mìn',
        ),
        actions: [
          IconButton(
            key: const Key('hint'),
            tooltip: 'Gợi ý (còn ${_maxHints - _hintsUsed})',
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: _useHint,
          ),
          if (!_daily)
            IconButton(
              key: const Key('level'),
              tooltip: 'Độ khó',
              icon: const Icon(Icons.tune),
              onPressed: _pickLevel,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _Counter(
                          icon: Icons.flag,
                          color: s.error,
                          text: '${_game.flagsLeft}',
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const Key('smiley'),
                      tooltip: _daily ? 'Chơi lại cùng đề' : 'Ván mới',
                      iconSize: 34,
                      icon: Icon(face),
                      onPressed: () => setState(_newGame),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _Counter(
                          icon: Icons.timer_outlined,
                          color: s.primary,
                          text: '$_seconds s',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _daily
                      ? 'Thử thách ngày · ${_game.rows}x${_game.cols} · ${_game.mines} mìn'
                      : '${_level.label} · ${_game.rows}x${_game.cols} · ${_game.mines} mìn'
                            '${best == null ? '' : ' · Kỷ lục: $best s'}',
                  style: t.bodySmall,
                ),
                const SizedBox(height: 8),
                Expanded(child: _board(s)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.touch_app),
                      label: Text('Mở ô'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.flag),
                      label: Text('Cắm cờ'),
                    ),
                  ],
                  selected: {_flagMode},
                  onSelectionChanged: (v) =>
                      setState(() => _flagMode = v.first),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nhấn giữ cắm cờ · Chạm số đủ cờ để mở các ô kề',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _board(ColorScheme s) {
    return LayoutBuilder(
      builder: (context, box) {
        final fit = box.maxWidth / _game.cols;
        final cell = fit.clamp(_minCell, 46.0);
        final w = cell * _game.cols;
        final h = cell * _game.rows;
        final reduce = _reduce;
        final boardW = max(box.maxWidth, w);
        final boardH = max(box.maxHeight, h);
        final grid = SizedBox(
          width: w,
          height: h,
          child: Column(
            children: [
              for (var r = 0; r < _game.rows; r++)
                Row(
                  children: [
                    for (var c = 0; c < _game.cols; c++)
                      _tile(r, c, cell, reduce),
                  ],
                ),
            ],
          ),
        );
        return Stack(
          children: [
            Positioned.fill(
              child: Shake(
                key: _shake,
                child: ClipRect(
                  child: InteractiveViewer(
                    key: ValueKey('viewer-$_gen'),
                    constrained: false,
                    minScale: 0.5,
                    maxScale: 3,
                    boundaryMargin: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: boardW,
                      height: boardH,
                      child: Center(child: grid),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: WinBanner(
                show: _game.won,
                title: 'Thắng!',
                subtitle: '$_seconds giây',
                onAgain: () => setState(_newGame),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(int r, int c, double size, bool reduce) {
    final cell = _game.cells[r][c];
    final i = r * _game.cols + c;
    final revealMine = _game.lost && cell.mine && !cell.flag;
    final wrongFlag = _game.lost && cell.flag && !cell.mine;
    final isBoom = _game.boom == (r, c);
    return GestureDetector(
      key: Key('cell-$r-$c'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _act(r, c, flag: _flagMode),
      onLongPress: () => _act(r, c, flag: true),
      onSecondaryTap: () => _act(r, c, flag: true),
      child: _Tile(
        key: ValueKey('$_gen-$r-$c'),
        size: size,
        data: (
          open: cell.open,
          flag: cell.flag && !wrongFlag,
          mine: revealMine,
          wrong: wrongFlag,
          near: cell.near,
          boom: isBoom,
        ),
        delay: reduce ? Duration.zero : (_delays[i] ?? Duration.zero),
        animate: !reduce,
        hint: _hint == i,
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

typedef _V = ({
  bool open,
  bool flag,
  bool mine,
  bool wrong,
  int near,
  bool boom,
});

/// Mot o: giu "hinh dang hien thi" rieng de co the tre (lan song / no lan luot)
/// roi moi chuyen, kem animation scale khi doi trang thai.
class _Tile extends StatefulWidget {
  const _Tile({
    required this.size,
    required this.data,
    required this.delay,
    required this.animate,
    required this.hint,
    super.key,
  });

  final double size;
  final _V data;
  final Duration delay;
  final bool animate;
  final bool hint;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  late _V _vis = widget.data;
  bool _anim = false;
  Timer? _t;

  @override
  void didUpdateWidget(_Tile old) {
    super.didUpdateWidget(old);
    if (widget.data == old.data) return;
    _t?.cancel();
    if (widget.data == _vis) return;
    if (widget.delay > Duration.zero) {
      _t = Timer(widget.delay, () {
        if (!mounted) return;
        setState(() {
          _anim = true;
          _vis = widget.data;
        });
      });
    } else {
      _anim = widget.animate;
      _vis = widget.data;
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Color _numColor(int n, ColorScheme s) => switch (n) {
    1 => Colors.blue,
    2 => Colors.green,
    3 => Colors.red,
    4 => Colors.indigo,
    _ => s.error,
  };

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final v = _vis;
    final shown = v.open || v.mine;
    final bg = v.mine
        ? s.errorContainer
        : v.open
        ? s.surfaceContainerHighest
        : s.primaryContainer;
    final fs = widget.size * 0.5;
    Widget? content;
    if (v.mine) {
      content = Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (_anim) _Ring(size: widget.size, color: s.error, strong: v.boom),
          Icon(Icons.brightness_7, size: fs + 2, color: s.onErrorContainer),
        ],
      );
    } else if (v.flag) {
      final icon = Icon(Icons.flag, size: fs + 2, color: s.error);
      content = _anim
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 380),
              curve: Curves.elasticOut,
              builder: (_, k, child) => Transform.translate(
                offset: Offset(0, -10 * (1 - k)),
                child: Transform.scale(scale: k.clamp(0.0, 1.4), child: child),
              ),
              child: icon,
            )
          : icon;
    } else if (v.wrong) {
      content = Icon(Icons.close, size: fs + 2, color: s.error);
    } else if (shown && v.near > 0) {
      content = Text(
        '${v.near}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: fs,
          color: _numColor(v.near, s),
        ),
      );
    }
    Widget box = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: widget.hint
            ? Border.all(color: s.tertiary, width: 3)
            : v.boom
            ? Border.all(color: s.error, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: content,
    );
    if (_anim && (v.open || v.mine)) {
      box = TweenAnimationBuilder<double>(
        key: ValueKey(('o', v.open, v.mine)),
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (_, k, child) => Transform.scale(scale: k, child: child),
        child: box,
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Padding(padding: const EdgeInsets.all(1), child: box),
    );
  }
}

/// Vong sang lan ra khi mot mine no.
class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.color, required this.strong});

  final double size;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: strong ? 600 : 450),
        builder: (_, k, _) => Opacity(
          opacity: (1 - k).clamp(0.0, 1.0),
          child: Container(
            width: size * (0.4 + (strong ? 2.0 : 1.4) * k),
            height: size * (0.4 + (strong ? 2.0 : 1.4) * k),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: strong ? 4 : 3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet chon do kho + tuy chinh kich thuoc va so min (co kiem tra hop le).
class _LevelSheet extends StatefulWidget {
  const _LevelSheet({
    required this.current,
    required this.custom,
    required this.bestOf,
  });

  final MineLevel current;
  final _Custom custom;
  final int? Function(MineLevel) bestOf;

  @override
  State<_LevelSheet> createState() => _LevelSheetState();
}

class _LevelSheetState extends State<_LevelSheet> {
  late int _rows = widget.custom.rows;
  late int _cols = widget.custom.cols;
  late int _mines = widget.custom.mines;

  void _pop(MineLevel l) =>
      Navigator.of(context).pop((l, (rows: _rows, cols: _cols, mines: _mines)));

  void _clampMines() =>
      _mines = _mines.clamp(1, Minesweeper.maxMinesFor(_rows, _cols));

  @override
  Widget build(BuildContext context) {
    final err = Minesweeper.validateConfig(_rows, _cols, _mines);
    final maxMines = Minesweeper.maxMinesFor(_rows, _cols);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in [MineLevel.easy, MineLevel.medium, MineLevel.hard])
              ListTile(
                key: Key('level-${l.key}'),
                selected: widget.current == l,
                leading: Icon(
                  widget.current == l
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(l.label),
                subtitle: Text(
                  '${l.rows}x${l.cols} · ${l.mines} mìn'
                  '${widget.bestOf(l) == null ? '' : ' · Kỷ lục ${widget.bestOf(l)} s'}',
                ),
                onTap: () => _pop(l),
              ),
            const Divider(),
            Text('Tuỳ chỉnh', style: Theme.of(context).textTheme.titleMedium),
            _slider(
              'Hàng',
              _rows,
              Minesweeper.minSide,
              Minesweeper.maxRows,
              (v) => setState(() {
                _rows = v;
                _clampMines();
              }),
            ),
            _slider(
              'Cột',
              _cols,
              Minesweeper.minSide,
              Minesweeper.maxCols,
              (v) => setState(() {
                _cols = v;
                _clampMines();
              }),
            ),
            _slider(
              'Mìn',
              _mines,
              1,
              maxMines,
              (v) => setState(() => _mines = v),
            ),
            if (err != null)
              Text(
                err,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('level-custom'),
                onPressed: err == null ? () => _pop(MineLevel.custom) : null,
                child: Text('Bắt đầu $_rows x $_cols · $_mines mìn'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.end)),
      ],
    );
  }
}
