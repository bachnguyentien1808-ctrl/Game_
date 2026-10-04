import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
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
    with WidgetsBindingObserver {
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
  (int, int)? _sel;
  final List<_Move> _undo = [];
  Set<(int, int)> _err = {};
  Set<int> _done = {};
  final Set<int> _flash = {};
  Timer? _timer;
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

  void _win() {
    final prev = _store.isDaily ? null : _store.stats(_bestKey).best;
    setState(() {
      _won = true;
      _newBest = !_store.isDaily && (prev == null || _secs < prev);
    });
    _store
      ..recordWin(_id, score: _secs, lowerIsBetter: true)
      ..clearState(_id);
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
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(_store.homeRoute)),
        title: Text(_store.isDaily ? 'Kakuro - Thử thách ngày' : 'Kakuro'),
        actions: [
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
                          child: Shake(key: _shake, child: _board(scheme)),
                        ),
                        const SizedBox(height: 14),
                        _toolRow(scheme),
                        const SizedBox(height: 10),
                        _numPad(scheme),
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
                onAgain: () => _newGame(_store.isDaily ? _dailyLevel : _level),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(ColorScheme scheme, int? best) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Chip(
          avatar: Icon(
            _store.isDaily ? Icons.today_outlined : Icons.signal_cellular_alt,
            size: 18,
          ),
          label: Text(
            _store.isDaily ? 'Hôm nay' : '${_lv.name} ${_lv.n}x${_lv.n}',
          ),
          visualDensity: VisualDensity.compact,
        ),
        const Spacer(),
        if (best != null) ...[
          Icon(Icons.emoji_events_outlined, size: 18, color: scheme.tertiary),
          const SizedBox(width: 4),
          Text(_fmt(best), style: t.bodyMedium),
          const SizedBox(width: 14),
        ],
        Icon(Icons.timer_outlined, size: 18, color: scheme.primary),
        const SizedBox(width: 4),
        Text(
          _fmt(_secs),
          style: t.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _board(ColorScheme scheme) {
    final size = _p.size;
    final sel = _sel;
    final selA = sel == null ? -1 : _p.acrossRunOf[sel.$1][sel.$2];
    final selD = sel == null ? -1 : _p.downRunOf[sel.$1][sel.$2];
    final green = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Theme.of(context).brightness,
    );
    final anim = !MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(
      builder: (context, box) {
        final cell = box.maxWidth / size;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.outlineVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.5),
            child: Column(
              children: [
                for (var r = 0; r < size; r++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var c = 0; c < size; c++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(0.75),
                              child: _p.isWhite(r, c)
                                  ? _whiteCell(
                                      r,
                                      c,
                                      cell,
                                      scheme,
                                      green,
                                      selA,
                                      selD,
                                      anim,
                                    )
                                  : _clueCell(r, c, scheme, selA, selD),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _clueCell(int r, int c, ColorScheme scheme, int selA, int selD) {
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
          bg: scheme.inverseSurface,
          fg: scheme.onInverseSurface,
          hi: scheme.inversePrimary,
          acrossActive: ai != -1 && ai == selA,
          downActive: di != -1 && di == selD,
          acrossDone: _done.contains(ai),
          downDone: _done.contains(di),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _whiteCell(
    int r,
    int c,
    double cell,
    ColorScheme scheme,
    ColorScheme green,
    int selA,
    int selD,
    bool anim,
  ) {
    final v = _v[r][c];
    final ai = _p.acrossRunOf[r][c];
    final di = _p.downRunOf[r][c];
    final isSel = _sel == (r, c);
    final err = _err.contains((r, c));
    final flash = _flash.contains(ai) || _flash.contains(di);
    final done = _done.contains(ai) || _done.contains(di);
    final peer = ai == selA || di == selD;
    final bg = err
        ? scheme.errorContainer
        : isSel
        ? scheme.primaryContainer
        : flash
        ? green.primary.withValues(alpha: 0.55)
        : done
        ? green.primaryContainer
        : peer
        ? scheme.surfaceContainerHighest
        : scheme.surface;
    final fg = err
        ? scheme.onErrorContainer
        : done && !isSel
        ? green.onPrimaryContainer
        : scheme.onSurface;
    Widget content;
    if (v != 0) {
      content = PopIn(
        trigger: 'v$r-$c-$v',
        duration: anim ? const Duration(milliseconds: 220) : Duration.zero,
        child: Text(
          '$v',
          style: TextStyle(
            fontSize: cell * 0.52,
            fontWeight: FontWeight.w600,
            color: fg,
            height: 1,
          ),
        ),
      );
    } else if (_notes[r][c] != 0) {
      content = _NotesGrid(
        mask: _notes[r][c],
        color: scheme.onSurfaceVariant,
        fontSize: cell * 0.2,
      );
    } else {
      content = const SizedBox.shrink();
    }
    Widget box = AnimatedContainer(
      duration: anim ? const Duration(milliseconds: 220) : Duration.zero,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
        border: isSel ? Border.all(color: scheme.primary, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: content,
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(r, c),
        child: box,
      ),
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
                  child: _pencil
                      ? OutlinedButton(
                          key: ValueKey('kakuro-num-$d'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _won ? null : () => _put(d),
                          child: Text(
                            '$d',
                            style: const TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : FilledButton.tonal(
                          key: ValueKey('kakuro-num-$d'),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _won ? null : () => _put(d),
                          child: Text(
                            '$d',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
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

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn = IconButton.filledTonal(
      isSelected: active,
      onPressed: onTap,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: active ? scheme.primary : null,
        foregroundColor: active ? scheme.onPrimary : null,
      ),
    );
    if (badge != null) {
      btn = Badge(
        label: Text('$badge'),
        backgroundColor: badge! > 0 ? scheme.primary : scheme.outline,
        textColor: scheme.onPrimary,
        child: btn,
      );
    }
    return Tooltip(
      message: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn,
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
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
    required this.bg,
    required this.fg,
    required this.hi,
    required this.acrossActive,
    required this.downActive,
    required this.acrossDone,
    required this.downDone,
  });

  final int across;
  final int down;
  final Color bg;
  final Color fg;
  final Color hi;
  final bool acrossActive;
  final bool downActive;
  final bool acrossDone;
  final bool downDone;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..color = across == 0 && down == 0 ? bg.withValues(alpha: 0.8) : bg,
    );
    if (across == 0 && down == 0) return;
    canvas.drawLine(
      Offset(size.width * 0.06, size.height * 0.06),
      Offset(size.width * 0.94, size.height * 0.94),
      Paint()
        ..color = fg.withValues(alpha: 0.35)
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
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active
                ? hi
                : done
                ? fg.withValues(alpha: 0.45)
                : fg,
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
      o.bg != bg ||
      o.fg != fg ||
      o.hi != hi ||
      o.acrossActive != acrossActive ||
      o.downActive != downActive ||
      o.acrossDone != acrossDone ||
      o.downDone != downDone;
}
