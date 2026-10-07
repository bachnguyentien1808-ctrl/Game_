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
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';
import 'package:puzzle_hub/games/kakuro/domain/kakuro_engine.dart';

const _id = 'kakuro';

class _Level {
  const _Level(this.name, this.n, this.density, this.hints);

  final String name;
  final int n;
  final double density;
  final int hints;
}

const _levels = <_Level>[
  _Level('Dễ', 5, 0.7, 3),
  _Level('Vừa', 6, 0.75, 3),
  _Level('Khó', 7, 0.8, 2),
];

/// Muc dung cho thu thach ngay.
const _dailyLevel = 1;

/// Mot buoc de hoan tac: o (r, c), gia tri cu, ghi chu cu.
typedef _Move = (int r, int c, int value, int notes);

String _fmt(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

class KakuroScreen extends ConsumerStatefulWidget {
  const KakuroScreen({super.key, this.daily});

  /// Khoa ngay yyyyMMdd neu choi thu thach ngay.
  final String? daily;

  @override
  ConsumerState<KakuroScreen> createState() => _KakuroScreenState();
}

class _KakuroScreenState extends ConsumerState<KakuroScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final GameStore _store = GameStore(
    ref.read(progressStoreProvider),
    daily: widget.daily,
  );
  late KakuroPuzzle _p;
  late List<List<int>> _v;
  late List<List<int>> _notes;
  int _level = 1;
  int _secs = 0;
  int _hints = 3;
  bool _won = false;
  bool _pencil = false;
  bool _paused = false;
  bool _newBest = false;
  int? _points;
  (int, int)? _sel;
  final List<_Move> _undo = [];
  Set<(int, int)> _err = {};
  Set<int> _done = {};
  final Set<int> _flash = {};
  Timer? _timer;
  // Thong bao hoan thanh doan: song burst + toast.
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  List<(int, int, int)> _burstCells = const []; // (r, c, thu tu trong doan)
  int _toastId = 0;
  String _toastText = '';
  final _shake = GlobalKey<ShakeState>();
  final _focus = FocusNode();

  _Level get _lv => _levels[_level];
  String get _bestKey => '$_id.n${_lv.n}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_restore()) _newGame(_store.isDaily ? _dailyLevel : 1, save: false);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _won || _paused) return;
      setState(() => _secs++);
      if (_secs % 10 == 0) _save();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _burst.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final pause = state != AppLifecycleState.resumed;
    if (pause && !_paused && !_won) _save();
    _paused = pause;
  }

  // ---------- Trang thai ----------

  bool _restore() {
    final s = _store.loadState(_id);
    if (s == null) return false;
    try {
      final p = KakuroPuzzle.fromJson(s['p']! as Map<String, dynamic>);
      final lv = s['lv']! as int;
      if (lv < 0 || lv >= _levels.length) return false;
      final n = p.size;
      List<List<int>> unflat(Object? o) {
        final l = (o! as List).cast<int>();
        if (l.length != n * n) throw const FormatException('do dai sai');
        return [for (var r = 0; r < n; r++) l.sublist(r * n, r * n + n)];
      }

      final v = unflat(s['v']);
      final m = unflat(s['m']);
      _p = p;
      _v = v;
      _notes = m;
      _level = lv;
      _secs = s['t'] as int? ?? 0;
      _hints = s['h'] as int? ?? _levels[lv].hints;
      _sel = _firstWhite();
      _recompute();
      if (_p.isSolved(_v)) return false;
      return true;
    } on Object {
      return false;
    }
  }

  void _save() {
    if (_won) return;
    _store.saveState(_id, {
      'p': _p.toJson(),
      'lv': _level,
      'v': _v.expand((r) => r).toList(),
      'm': _notes.expand((r) => r).toList(),
      't': _secs,
      'h': _hints,
    });
  }

  void _newGame(int level, {bool save = true}) {
    final lv = _levels[level];
    _level = level;
    _p = KakuroPuzzle.generate(
      n: lv.n,
      density: lv.density,
      rng: _store.rngFor(_id),
    );
    _v = _p.emptyGrid();
    _notes = _p.emptyGrid();
    _secs = 0;
    _hints = lv.hints;
    _won = false;
    _newBest = false;
    _points = null;
    _undo.clear();
    _flash.clear();
    _sel = _firstWhite();
    _recompute();
    _store.recordStart(_id);
    _save();
    if (save) setState(() {});
  }

  (int, int)? _firstWhite() {
    for (var r = 0; r < _p.size; r++) {
      for (var c = 0; c < _p.size; c++) {
        if (_p.isWhite(r, c)) return (r, c);
      }
    }
    return null;
  }

  void _recompute() {
    _err = _p.errors(_v);
    _done = {
      for (var i = 0; i < _p.runs.length; i++)
        if (_p.runSolved(_v, _p.runs[i])) i,
    };
  }

  // ---------- Thao tac ----------

  void _select(int r, int c) {
    if (!_p.isWhite(r, c)) return;
    GameFx.tap();
    Sfx.play(SfxKind.tap);
    setState(() => _sel = (r, c));
    _focus.requestFocus();
  }

  void _put(int d, {bool fromHint = false}) {
    final s = _sel;
    if (s == null || _won) return;
    final (r, c) = s;
    if (_pencil && d != 0 && !fromHint) {
      if (_v[r][c] != 0) return;
      _undo.add((r, c, _v[r][c], _notes[r][c]));
      setState(() => _notes[r][c] ^= 1 << d);
      GameFx.tap();
      Sfx.play(SfxKind.tap);
      _save();
      return;
    }
    if (_v[r][c] == d && (d != 0 || _notes[r][c] == 0)) return;
    _undo.add((r, c, _v[r][c], _notes[r][c]));
    final oldErr = _err;
    final oldDone = _done;
    setState(() {
      _v[r][c] = d;
      _notes[r][c] = 0; // dien so hoac xoa deu bo ghi chu cua o
      _recompute();
    });
    _afterChange(s, d, oldErr, oldDone);
  }

  void _afterChange(
    (int, int) cell,
    int d,
    Set<(int, int)> oldErr,
    Set<int> oldDone,
  ) {
    final fresh = _done.difference(oldDone);
    final newError = d != 0 && _err.contains(cell) && !oldErr.contains(cell);
    if (newError) {
      _shake.currentState?.shake();
      GameFx.error();
      Sfx.play(SfxKind.error);
    } else if (fresh.isNotEmpty) {
      GameFx.success();
      Sfx.play(SfxKind.match);
      setState(() => _flash.addAll(fresh));
      _announceRuns(fresh);
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _flash.removeAll(fresh));
      });
    } else if (d == 0) {
      GameFx.tap();
      Sfx.play(SfxKind.erase);
    } else {
      GameFx.tap();
      Sfx.play(SfxKind.place);
    }
    if (_p.isSolved(_v)) {
      _win();
    } else {
      _save();
    }
  }

  /// Burst + toast khi mot doan vua chuyen sang dung (khong goi khi tai/hoan tac).
  void _announceRuns(Set<int> fresh) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    final ids = fresh.toList()..sort();
    setState(() {
      _toastId++;
      _toastText = ids.length == 1
          ? 'Đoạn ${_p.runs[ids.first].sum} xong!'
          : '${ids.length} đoạn xong!';
      _burstCells = [
        for (final i in ids)
          for (var k = 0; k < _p.runs[i].cells.length; k++)
            (_p.runs[i].cells[k].$1, _p.runs[i].cells[k].$2, k),
      ];
    });
    _burst.forward(from: 0);
  }

  void _win() {
    final prev = _store.isDaily ? null : _store.stats(_bestKey).best;
    setState(() {
      _won = true;
      _newBest = !_store.isDaily && (prev == null || _secs < prev);
    });
    _store
      ..recordWin(_id, score: _secs, lowerIsBetter: true)
      ..clearState(_id);
    final pts = Scoring.points(
      base: 1000,
      seconds: _secs,
      parSeconds: const [420, 720, 1080][_level],
      mult: const [1.0, 1.5, 2.0][_level],
      hints: (_lv.hints - _hints).clamp(0, _lv.hints),
    );
    setState(() => _points = pts);
    _store.awardPoints(_id, pts);
    if (!_store.isDaily) {
      _store.recordScore(_bestKey, _secs, lowerIsBetter: true);
    }
    GameFx.success();
    Sfx.play(SfxKind.win);
  }

  void _undoMove() {
    if (_undo.isEmpty || _won) return;
    final (r, c, v, m) = _undo.removeLast();
    setState(() {
      _v[r][c] = v;
      _notes[r][c] = m;
      _sel = (r, c);
      _recompute();
    });
    GameFx.tap();
    Sfx.play(SfxKind.erase);
    _save();
  }

  void _hint() {
    if (_won) return;
    if (_hints <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Đã hết lượt gợi ý')));
      return;
    }
    (int, int)? target;
    final s = _sel;
    if (s != null && _v[s.$1][s.$2] != _p.solution[s.$1][s.$2]) {
      target = s;
    } else {
      outer:
      for (var r = 0; r < _p.size; r++) {
        for (var c = 0; c < _p.size; c++) {
          if (_p.isWhite(r, c) && _v[r][c] != _p.solution[r][c]) {
            target = (r, c);
            break outer;
          }
        }
      }
    }
    if (target == null) return;
    setState(() {
      _hints--;
      _sel = target;
    });
    _put(_p.solution[target.$1][target.$2], fromHint: true);
  }

  void _moveSel(int dr, int dc) {
    final s = _sel ?? _firstWhite();
    if (s == null) return;
    var (r, c) = s;
    for (var i = 0; i < _p.size; i++) {
      r = (r + dr) % _p.size;
      c = (c + dc) % _p.size;
      if (r < 0) r += _p.size;
      if (c < 0) c += _p.size;
      if (_p.isWhite(r, c)) {
        setState(() => _sel = (r, c));
        return;
      }
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final ch = e.character;
    if (ch != null && ch.length == 1) {
      final d = int.tryParse(ch);
      if (d != null && d >= 1) {
        _put(d);
        return KeyEventResult.handled;
      }
      if (ch == 'n' || ch == 'N') {
        setState(() => _pencil = !_pencil);
        return KeyEventResult.handled;
      }
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      _put(0);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _moveSel(-1, 0);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _moveSel(1, 0);
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _moveSel(0, -1);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _moveSel(0, 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---------- Giao dien ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final best = _store.isDaily ? null : _store.stats(_bestKey).best;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: BackButton(onPressed: () => context.go(_store.homeRoute)),
        title: Text(_store.isDaily ? 'Kakuro - Thử thách ngày' : 'Kakuro'),
        actions: [
          const ScoreChip(),
          const HelpAction(gameId: 'kakuro'),
          if (_store.isDaily)
            IconButton(
              tooltip: 'Chơi lại đề hôm nay',
              icon: const Icon(Icons.refresh),
              onPressed: () => _newGame(_dailyLevel),
            )
          else
            PopupMenuButton<int>(
              tooltip: 'Ván mới',
              icon: const Icon(Icons.refresh),
              onSelected: _newGame,
              itemBuilder: (_) => [
                for (var i = 0; i < _levels.length; i++)
                  PopupMenuItem(
                    value: i,
                    child: Text(
                      'Ván mới - ${_levels[i].name} '
                      '(${_levels[i].n}x${_levels[i].n})',
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _statusRow(scheme, best),
                        const SizedBox(height: 10),
                        AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: Shake(
                                  key: _shake,
                                  child: _board(scheme),
                                ),
                              ),
                              if (_toastText.isNotEmpty)
                                Positioned(
                                  top: -14,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: _RunToast(
                                      key: ValueKey(_toastId),
                                      text: _toastText,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        GlassPanel(
                          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _toolRow(scheme),
                              const SizedBox(height: 10),
                              _numPad(scheme),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: WinBanner(
                show: _won,
                title: 'Hoàn thành!',
                subtitle: _newBest
                    ? 'Kỷ lục mới ${_fmt(_secs)}'
                    : 'Thời gian ${_fmt(_secs)}',
                points: _points,
                onAgain: () => _newGame(_store.isDaily ? _dailyLevel : _level),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(ColorScheme scheme, int? best) {
    Widget fit(Widget w) => Flexible(
      child: FittedBox(fit: BoxFit.scaleDown, child: w),
    );
    return GlassBar(
      children: [
        fit(
          GlassStat(
            icon: _store.isDaily
                ? Icons.today_outlined
                : Icons.signal_cellular_alt,
            colors: Candy.purple,
            text: _store.isDaily ? 'Hôm nay' : '${_lv.name} ${_lv.n}x${_lv.n}',
          ),
        ),
        if (best != null)
          fit(
            GlassStat(
              icon: Icons.emoji_events_outlined,
              colors: Candy.orange,
              text: _fmt(best),
            ),
          ),
        fit(GlassStat(icon: Icons.timer_outlined, text: _fmt(_secs))),
      ],
    );
  }

  Widget _board(ColorScheme scheme) {
    final size = _p.size;
    final sel = _sel;
    final selA = sel == null ? -1 : _p.acrossRunOf[sel.$1][sel.$2];
    final selD = sel == null ? -1 : _p.downRunOf[sel.$1][sel.$2];
    final anim = !MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(
      builder: (context, box) {
        final cell = box.maxWidth / size;
        return Stack(
          children: [
            CandyFrame(
              padding: 5,
              child: Column(
                children: [
                  for (var r = 0; r < size; r++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var c = 0; c < size; c++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(0.9),
                                child: _p.isWhite(r, c)
                                    ? _whiteCell(r, c, cell, selA, selD, anim)
                                    : _clueCell(r, c, selA, selD),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _burst,
                  builder: (_, _) => CustomPaint(
                    painter: _RunBurstPainter(
                      _burstCells,
                      _burst.value,
                      size,
                      5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _clueCell(int r, int c, int selA, int selD) {
    final a = _p.across[r][c];
    final d = _p.down[r][c];
    final ai = a == 0 ? -1 : _p.acrossRunOf[r][c + 1];
    final di = d == 0 ? -1 : _p.downRunOf[r + 1][c];
    return Semantics(
      label: [if (a != 0) 'ngang $a', if (d != 0) 'dọc $d'].join(', '),
      child: CustomPaint(
        painter: _CluePainter(
          across: a,
          down: d,
          acrossActive: ai != -1 && ai == selA,
          downActive: di != -1 && di == selD,
          acrossDone: _done.contains(ai),
          downDone: _done.contains(di),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _whiteCell(int r, int c, double cell, int selA, int selD, bool anim) {
    final v = _v[r][c];
    final ai = _p.acrossRunOf[r][c];
    final di = _p.downRunOf[r][c];
    final isSel = _sel == (r, c);
    final err = _err.contains((r, c));
    final flash = _flash.contains(ai) || _flash.contains(di);
    final done = _done.contains(ai) || _done.contains(di);
    final peer = ai == selA || di == selD;
    final List<Color> colors;
    final Color fg;
    if (err) {
      colors = Candy.red;
      fg = Colors.white;
    } else if (isSel) {
      colors = Candy.blue;
      fg = Colors.white;
    } else if (flash) {
      colors = Candy.green;
      fg = Colors.white;
    } else if (done) {
      colors = const [Color(0xFFE6F9D2), Color(0xFFB4E592)];
      fg = const Color(0xFF1F5A1A);
    } else if (peer) {
      colors = const [Color(0xFFEAF5FF), Color(0xFFC3DEF5)];
      fg = const Color(0xFF16345C);
    } else {
      colors = const [Color(0xFFFFFFFF), Color(0xFFE9EEF6)];
      fg = const Color(0xFF16345C);
    }
    // So nguoi choi dien: xanh duong (tru khi dang chon / loi / vua xong).
    final digit = v != 0 && !err && !isSel && !flash && !done
        ? const Color(0xFF1E6FE0)
        : fg;
    Widget content;
    if (v != 0) {
      content = PopIn(
        trigger: 'v$r-$c-$v',
        duration: anim ? const Duration(milliseconds: 220) : Duration.zero,
        child: Text(
          '$v',
          style: TextStyle(
            fontSize: cell * 0.52,
            fontWeight: FontWeight.w800,
            color: digit,
            height: 1,
          ),
        ),
      );
    } else if (_notes[r][c] != 0) {
      content = _NotesGrid(
        mask: _notes[r][c],
        color: isSel ? Colors.white : const Color(0xFF5B6B85),
        fontSize: cell * 0.2,
      );
    } else {
      content = const SizedBox.shrink();
    }
    Widget box = AnimatedContainer(
      duration: anim ? const Duration(milliseconds: 220) : Duration.zero,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: isSel
            ? Border.all(color: const Color(0xFFBFE6FF), width: 2)
            : null,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: [
          const BoxShadow(color: Color(0x66000000), offset: Offset(0, 1.5)),
          if (isSel) const BoxShadow(color: Color(0x995CC8FF), blurRadius: 8),
          if (flash) const BoxShadow(color: Color(0xAAA5E05B), blurRadius: 8),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CandyGloss(radius: 4, opacity: 0.5),
          Center(child: content),
        ],
      ),
    );
    if (isSel && anim) {
      box = TweenAnimationBuilder<double>(
        key: ValueKey('sel$r-$c'),
        tween: Tween(begin: 0.82, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: box,
      );
    }
    return Semantics(
      button: true,
      selected: isSel,
      label: 'Ô hàng $r cột $c${v == 0 ? ', trống' : ', $v'}',
      child: _PressScale(onTap: () => _select(r, c), child: box),
    );
  }

  Widget _toolRow(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Tool(
          icon: Icons.undo,
          label: 'Hoàn tác',
          onTap: _undo.isEmpty || _won ? null : _undoMove,
        ),
        _Tool(
          icon: Icons.backspace_outlined,
          label: 'Xoá',
          onTap: _won ? null : () => _put(0),
        ),
        _Tool(
          icon: _pencil ? Icons.edit : Icons.edit_outlined,
          label: _pencil ? 'Ghi chú: bật' : 'Ghi chú',
          active: _pencil,
          toggle: true,
          onTap: () {
            GameFx.tap();
            setState(() => _pencil = !_pencil);
          },
        ),
        _Tool(
          icon: Icons.lightbulb_outline,
          label: 'Gợi ý',
          badge: _hints,
          onTap: _won ? null : _hint,
        ),
      ],
    );
  }

  Widget _numPad(ColorScheme scheme) {
    final sel = _sel;
    final used = <int>{};
    if (sel != null) {
      for (final i in [
        _p.acrossRunOf[sel.$1][sel.$2],
        _p.downRunOf[sel.$1][sel.$2],
      ]) {
        if (i < 0) continue;
        for (final (r, c) in _p.runs[i].cells) {
          if ((r, c) != sel && _v[r][c] != 0) used.add(_v[r][c]);
        }
      }
    }
    return Row(
      children: [
        for (var d = 1; d <= 9; d++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: SizedBox(
                height: 54,
                child: AnimatedOpacity(
                  opacity: used.contains(d) ? 0.4 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: CandyButton(
                    key: ValueKey('kakuro-num-$d'),
                    radius: 10,
                    padding: EdgeInsets.zero,
                    colors: _pencil ? Candy.orange : Candy.blue,
                    dim: _won,
                    onPressed: _won ? null : () => _put(d),
                    child: Text(
                      '$d',
                      style: TextStyle(
                        fontSize: _pencil ? 18 : 22,
                        fontStyle: _pencil ? FontStyle.italic : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Nhan xuong thi thu nho nhe (phan hoi cham), nha ra thi bung lai.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.88 : 1,
        duration: const Duration(milliseconds: 80),
        child: widget.child,
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.toggle = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  /// Nut bat/tat: sang khi [active], mo khi tat.
  final bool toggle;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    Widget btn = CandyButton(
      onPressed: onTap,
      colors: toggle ? Candy.orange : Candy.blue,
      dim: onTap == null || (toggle && !active),
      padding: const EdgeInsets.all(10),
      child: Icon(icon),
    );
    if (badge != null) {
      btn = Badge(
        label: Text('$badge'),
        backgroundColor: badge! > 0 ? Candy.red.last : const Color(0xFF5B6B85),
        textColor: Colors.white,
        child: btn,
      );
    }
    return Tooltip(
      message: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn,
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: GlassStyle.of(context).pill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: GlassStyle.of(context).pillText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({
    required this.mask,
    required this.color,
    required this.fontSize,
  });

  final int mask;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: fontSize, color: color, height: 1);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        children: [
          for (var row = 0; row < 3; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: Center(
                        child: Text(
                          mask & (1 << (row * 3 + col + 1)) != 0
                              ? '${row * 3 + col + 1}'
                              : '',
                          style: style,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// O goi y: duong cheo, tong ngang o goc tren-phai, tong doc o goc duoi-trai.
class _CluePainter extends CustomPainter {
  _CluePainter({
    required this.across,
    required this.down,
    required this.acrossActive,
    required this.downActive,
    required this.acrossDone,
    required this.downDone,
  });

  final int across;
  final int down;
  final bool acrossActive;
  final bool downActive;
  final bool acrossDone;
  final bool downDone;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    final empty = across == 0 && down == 0;
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: empty
              ? const [Color(0xFF24344F), Color(0xFF16233A)]
              : const [Color(0xFF4A6FA8), Color(0xFF223A63)],
        ).createShader(rect),
    );
    if (empty) return;
    // Vet bong o nua tren.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1.5, 1, size.width - 3, size.height * 0.42),
        const Radius.circular(4),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(rect),
    );
    canvas.drawLine(
      Offset(size.width * 0.06, size.height * 0.06),
      Offset(size.width * 0.94, size.height * 0.94),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 1,
    );
    final fs = size.width * 0.3;
    void label(
      int v,
      Offset center, {
      required bool active,
      required bool done,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$v',
          style: TextStyle(
            fontSize: fs,
            height: 1,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            color: active
                ? const Color(0xFFFFE066)
                : done
                ? Candy.green.first
                : Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }

    if (across != 0) {
      label(
        across,
        Offset(size.width * 0.7, size.height * 0.3),
        active: acrossActive,
        done: acrossDone,
      );
    }
    if (down != 0) {
      label(
        down,
        Offset(size.width * 0.3, size.height * 0.72),
        active: downActive,
        done: downDone,
      );
    }
  }

  @override
  bool shouldRepaint(_CluePainter o) =>
      o.across != across ||
      o.down != down ||
      o.acrossActive != acrossActive ||
      o.downActive != downActive ||
      o.acrossDone != acrossDone ||
      o.downDone != downDone;
}

/// Song burst: moi o cua doan vua xong toa vong xanh + sao, lan theo thu tu.
class _RunBurstPainter extends CustomPainter {
  const _RunBurstPainter(this.cells, this.t, this.n, this.inset);

  final List<(int, int, int)> cells;
  final double t;
  final int n;
  final double inset;

  static const _colors = [
    Color(0xFFFFEB3B),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFFF80AB),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1 || cells.isEmpty) return;
    final cell = (size.width - 2 * inset) / n;
    for (final (r, c, idx) in cells) {
      final lt = ((t - idx * 0.07) / 0.55).clamp(0.0, 1.0);
      if (lt <= 0 || lt >= 1) continue;
      final ctr = Offset(inset + (c + .5) * cell, inset + (r + .5) * cell);
      final e = Curves.easeOutCubic.transform(lt);
      final fade = 1 - lt;
      canvas.drawCircle(
        ctr,
        cell * (.35 + .5 * e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * fade + 1
          ..color = const Color(0xFF2EC27E).withValues(alpha: fade),
      );
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4 + .3;
        final p = ctr + Offset(cos(a), sin(a)) * (cell * (.3 + .6 * e));
        final paint = Paint()
          ..color = _colors[i % _colors.length].withValues(alpha: fade);
        final star = Path();
        final k = cell * .08 * (1 - lt * .5);
        for (var j = 0; j < 8; j++) {
          final rad = j.isEven ? k * 1.6 : k * .6;
          final b = -pi / 2 + j * pi / 4;
          final pt = p + Offset(cos(b), sin(b)) * rad;
          j == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(star..close(), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RunBurstPainter o) => o.t != t || o.cells != cells;
}

/// Bong bong xanh noi len tren ban co khi hoan thanh doan.
class _RunToast extends StatelessWidget {
  const _RunToast({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
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
                text,
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
