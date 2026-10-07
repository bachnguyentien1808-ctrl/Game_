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
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_game.dart';
import 'package:puzzle_hub/games/sudoku/presentation/sudoku_board.dart';
import 'package:puzzle_hub/games/sudoku/presentation/sudoku_controls.dart';

const _id = 'sudoku';

/// Khoa cai dat rieng cua Sudoku (gioi han loi), khong theo che do ngay.
const _cfgKey = 'sudoku.cfg';

/// Do kho co dinh cua thu thach ngay.
const dailyLevel = SudokuLevel.medium;

class SudokuScreen extends ConsumerStatefulWidget {
  const SudokuScreen({super.key, this.daily});

  /// Khoa ngay yyyyMMdd neu la thu thach ngay.
  final String? daily;

  @override
  ConsumerState<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends ConsumerState<SudokuScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final GameStore _store;
  late final ProgressStore _ps;

  /// null = dang o man chon do kho (che do thuong).
  SudokuGame? _game;
  int _gen = 0;
  int? _sel;
  bool _notes = false;
  bool _paused = false;
  bool _appActive = true;
  bool _limitCfg = true;

  Timer? _timer;
  final ValueNotifier<int> _clock = ValueNotifier(0);

  String? _hintText;
  List<int> _hintUnit = const [];
  int? _hintCell;

  late final AnimationController _wave = AnimationController(vsync: this);
  Map<int, double> _waveDelay = const {};
  final _shakeKey = GlobalKey<ShakeState>();
  final _focus = FocusNode(debugLabel: 'sudoku');

  bool _showWin = false;
  bool _showResult = false;
  bool _newRecord = false;
  int? _best;
  Timer? _resultTimer;

  bool get _daily => _store.isDaily;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ps = ref.read(progressStoreProvider);
    _store = GameStore(_ps, daily: widget.daily);
    _limitCfg = _ps.loadState(_cfgKey)?['ml'] as bool? ?? true;
    final saved = _store.loadState(_id);
    if (saved != null) {
      try {
        final g = SudokuGame.fromJson(saved);
        if (!g.isOver) _game = g;
      } on Object {
        // Trang thai hong -> bat dau lai.
      }
    }
    if (_game == null && _daily) _startNew(dailyLevel, notify: false);
    _clock.value = _game?.elapsed ?? 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _resultTimer?.cancel();
    _wave.dispose();
    _clock.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _appActive = s == AppLifecycleState.resumed;
    if (!_appActive && _game != null && !_game!.isOver) {
      _save();
      if (!_paused) setState(() => _paused = true);
    }
  }

  // ---------- Vong doi van ----------

  void _tick() {
    final g = _game;
    if (g == null || g.isOver || _paused || !_appActive) return;
    g.elapsed++;
    _clock.value = g.elapsed;
    if (g.elapsed % 5 == 0) _save();
  }

  void _save() {
    final g = _game;
    if (g == null || g.isOver) return;
    _store.saveState(_id, g.toJson());
  }

  void _startNew(SudokuLevel level, {bool notify = true}) {
    final seed = _daily ? _store.rngFor(_id)!.nextInt(1 << 31) : null;
    final gen = SudokuEngine.generateLevel(level, seed: seed);
    void apply() {
      _game = SudokuGame.fresh(gen, level, mistakeLimit: _limitCfg);
      _gen++;
      _resetUi();
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
    _clock.value = 0;
    _store
      ..recordStart(_id)
      ..recordStart(level.statsId);
    _save();
    Sfx.play(SfxKind.flip);
  }

  void _resetUi() {
    _sel = null;
    _notes = false;
    _paused = false;
    _hintText = null;
    _hintUnit = const [];
    _hintCell = null;
    _showWin = false;
    _showResult = false;
    _newRecord = false;
    _waveDelay = const {};
    _resultTimer?.cancel();
    _wave.value = 0;
  }

  void _restartSame() {
    final g = _game;
    if (g == null) return;
    setState(() {
      g
        ..restart()
        ..mistakeLimit = _limitCfg;
      _gen++;
      _resetUi();
    });
    _clock.value = 0;
    _save();
    Sfx.play(SfxKind.flip);
  }

  void _backToPicker() {
    if (_daily) {
      context.go(_store.homeRoute);
      return;
    }
    _store.clearState(_id);
    setState(() {
      _game = null;
      _gen++;
      _resetUi();
    });
  }

  // ---------- Thao tac ----------

  void _select(int i) {
    if (_paused || _game == null) return;
    setState(() {
      _sel = i;
      if (_hintCell != null && _hintCell != i) _clearHint();
    });
    Sfx.play(SfxKind.tap);
    _focus.requestFocus();
  }

  void _clearHint() {
    _hintText = null;
    _hintUnit = const [];
    _hintCell = null;
  }

  void _digit(int d) {
    final g = _game;
    final i = _sel;
    if (g == null || i == null || _paused || g.isOver) return;
    if (_notes) {
      if (g.toggleNote(i, d)) {
        setState(_clearHint);
        Sfx.play(SfxKind.tap);
        GameFx.tap();
        _save();
      }
      return;
    }
    final r = g.place(i, d);
    if (!r.changed) return;
    setState(_clearHint);
    _afterPlace(i, r);
  }

  void _afterPlace(int i, PlaceResult r) {
    final g = _game!;
    if (r.wrong) {
      Sfx.play(SfxKind.error);
      GameFx.error();
      _shakeKey.currentState?.shake();
      if (g.isLost) {
        _onLose();
        return;
      }
    } else {
      Sfx.play(SfxKind.place);
      GameFx.tap();
      if (g.isWon) {
        _onWin(i);
        return;
      }
      if (r.completed.isNotEmpty) {
        Sfx.play(SfxKind.success);
        GameFx.success();
        _runUnitWave(i, r.completed);
      }
    }
    _save();
  }

  void _erase() {
    final g = _game;
    final i = _sel;
    if (g == null || i == null || _paused) return;
    if (g.erase(i)) {
      setState(_clearHint);
      Sfx.play(SfxKind.erase);
      GameFx.tap();
      _save();
    }
  }

  void _undo() {
    final g = _game;
    if (g == null || _paused) return;
    final i = g.undo();
    if (i == null) return;
    setState(() {
      _sel = i;
      _clearHint();
    });
    Sfx.play(SfxKind.erase);
    _save();
  }

  void _redo() {
    final g = _game;
    if (g == null || _paused) return;
    final i = g.redo();
    if (i == null) return;
    setState(() {
      _sel = i;
      _clearHint();
    });
    Sfx.play(SfxKind.place);
    _save();
  }

  void _hint() {
    final g = _game;
    if (g == null || _paused || g.isOver) return;
    final h = g.useHint(_sel);
    if (h == null) return;
    setState(() {
      _sel = h.index;
      _hintText = h.explanation;
      _hintUnit = h.unit;
      _hintCell = h.index;
    });
    Sfx.play(SfxKind.match);
    _afterPlace(h.index, h.place);
  }

  void _togglePause() {
    final g = _game;
    if (g == null || g.isOver) return;
    setState(() => _paused = !_paused);
    Sfx.play(SfxKind.tap);
    if (_paused) _save();
  }

  void _setLimit(bool on) {
    _limitCfg = on;
    _ps.saveState(_cfgKey, {'ml': on});
    final g = _game;
    setState(() {
      // Khong bat lai giua van neu da cham 3 loi (se thua ngay).
      if (g != null && !(on && g.mistakes >= SudokuGame.maxMistakes)) {
        g.mistakeLimit = on;
      }
    });
    _save();
  }

  // ---------- Hieu ung ----------

  bool get _reduce => MediaQuery.disableAnimationsOf(context);

  void _runUnitWave(int origin, List<List<int>> units) {
    if (_reduce) return;
    final d = <int, double>{};
    for (final u in units) {
      for (final j in u) {
        final dist = max(
          (j ~/ 9 - origin ~/ 9).abs(),
          (j % 9 - origin % 9).abs(),
        );
        final v = dist / 8;
        d[j] = d.containsKey(j) ? min(d[j]!, v) : v;
      }
    }
    _playWave(d, const Duration(milliseconds: 750));
  }

  void _runBoardWave(int origin) {
    if (_reduce) return;
    final d = <int, double>{
      for (var j = 0; j < 81; j++)
        j: ((j ~/ 9 - origin ~/ 9).abs() + (j % 9 - origin % 9).abs()) / 16,
    };
    _playWave(d, const Duration(milliseconds: 1300));
  }

  void _playWave(Map<int, double> d, Duration dur) {
    setState(() => _waveDelay = d);
    _wave
      ..duration = dur
      ..forward(from: 0);
  }

  void _onWin(int origin) {
    final g = _game!;
    final t = g.elapsed;
    if (!_daily) {
      final prev = _store.stats(g.level.statsId).best;
      _newRecord = prev == null || t < prev;
      _best = _newRecord ? t : prev;
      _store.recordWin(g.level.statsId, score: t, lowerIsBetter: true);
    }
    _store
      ..recordWin(_id, score: t, lowerIsBetter: true)
      ..clearState(_id);
    Sfx.play(SfxKind.win);
    GameFx.success();
    setState(() {
      _sel = null;
      _showWin = true;
      _clearHint();
    });
    _runBoardWave(origin);
    _resultTimer = Timer(Duration(milliseconds: _reduce ? 0 : 1600), () {
      if (mounted) setState(() => _showResult = true);
    });
  }

  void _onLose() {
    _store.clearState(_id);
    setState(() {
      _showResult = true;
      _clearHint();
    });
  }

  void _continueWithoutLimit() {
    final g = _game;
    if (g == null) return;
    setState(() {
      g.mistakeLimit = false;
      _showResult = false;
    });
    _save();
  }

  // ---------- Ban phim may tinh ----------

  static final Map<LogicalKeyboardKey, int> _digitKeys = {
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };

  static final Map<LogicalKeyboardKey, (int, int)> _arrows = {
    LogicalKeyboardKey.arrowUp: (-1, 0),
    LogicalKeyboardKey.arrowDown: (1, 0),
    LogicalKeyboardKey.arrowLeft: (0, -1),
    LogicalKeyboardKey.arrowRight: (0, 1),
  };

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final g = _game;
    if (g == null) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final hw = HardwareKeyboard.instance;
    final ctrl = hw.isControlPressed || hw.isMetaPressed;
    if (ctrl && k == LogicalKeyboardKey.keyZ) {
      hw.isShiftPressed ? _redo() : _undo();
      return KeyEventResult.handled;
    }
    if (ctrl && k == LogicalKeyboardKey.keyY) {
      _redo();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.keyP) {
      _togglePause();
      return KeyEventResult.handled;
    }
    if (_paused) return KeyEventResult.ignored;
    final d = _digitKeys[k];
    if (d != null) {
      _digit(d);
      return KeyEventResult.handled;
    }
    final a = _arrows[k];
    if (a != null) {
      final cur = _sel ?? 40;
      final r = (cur ~/ 9 + a.$1 + 9) % 9;
      final c = (cur % 9 + a.$2 + 9) % 9;
      _select(r * 9 + c);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace ||
        k == LogicalKeyboardKey.delete ||
        k == LogicalKeyboardKey.digit0 ||
        k == LogicalKeyboardKey.numpad0) {
      _erase();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyN) {
      setState(() => _notes = !_notes);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyH) {
      _hint();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------- Giao dien ----------

  Future<void> _openLevelSheet() async {
    final picked = await showModalBottomSheet<SudokuLevel>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ván mới',
                style: Theme.of(ctx).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SudokuLevelPicker(
                stats: (l) => _store.stats(l.statsId),
                current: _game?.level,
                onPick: (l) => Navigator.pop(ctx, l),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) _startNew(picked);
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final reduce = _reduce;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(_store.homeRoute)),
        title: Text(_daily ? 'Sudoku · Thử thách ngày' : 'Sudoku'),
        actions: [
          const HelpAction(gameId: 'sudoku'),
          if (g != null && !_daily)
            IconButton(
              tooltip: 'Ván mới',
              icon: const Icon(Icons.add_box_outlined),
              onPressed: _openLevelSheet,
            ),
          PopupMenuButton<String>(
            tooltip: 'Tuỳ chọn',
            onSelected: (v) {
              if (v == 'limit') _setLimit(!_limitCfg);
              if (v == 'restart') _restartSame();
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'limit',
                checked: _limitCfg,
                child: const Text('Giới hạn 3 lỗi'),
              ),
              if (g != null)
                const PopupMenuItem(
                  value: 'restart',
                  child: ListTile(
                    leading: Icon(Icons.replay),
                    title: Text('Chơi lại đề này'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: AnimatedSwitcher(
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOut,
            child: KeyedSubtree(
              key: ValueKey(_gen),
              child: g == null ? _pickerView() : _gameView(g),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pickerView() {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.grid_on,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'Chọn độ khó',
                style: t.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SudokuLevelPicker(
                stats: (l) => _store.stats(l.statsId),
                onPick: _startNew,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameView(SudokuGame g) {
    final s = Theme.of(context).colorScheme;
    final reduce = _reduce;
    final remaining = [for (var d = 1; d <= 9; d++) 9 - g.countOf(d)];
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _infoBar(g),
                  const SizedBox(height: 8),
                  Shake(
                    key: _shakeKey,
                    child: AnimatedSwitcher(
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      child: _paused
                          ? _pauseCover()
                          : SudokuBoard(
                              key: const ValueKey('board'),
                              game: g,
                              selected: _sel,
                              onTap: _select,
                              wave: _wave,
                              waveDelay: _waveDelay,
                              hintUnit: _hintUnit,
                              hintCell: _hintCell,
                            ),
                    ),
                  ),
                  AnimatedSize(
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    child: _hintText == null
                        ? const SizedBox(width: double.infinity, height: 8)
                        : _hintCard(s),
                  ),
                  SudokuActions(
                    canUndo: g.canUndo && !_paused,
                    canRedo: g.canRedo && !_paused,
                    notesOn: _notes,
                    hintsLeft: g.hintsLeft,
                    onUndo: _undo,
                    onRedo: _redo,
                    onErase: _erase,
                    onNotes: () {
                      setState(() => _notes = !_notes);
                      Sfx.play(SfxKind.tap);
                    },
                    onHint: _hint,
                  ),
                  const SizedBox(height: 8),
                  SudokuNumPad(
                    remaining: remaining,
                    notesOn: _notes,
                    onDigit: _digit,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: WinBanner(
            show: _showWin && !_showResult,
            title: 'Hoàn thành!',
            subtitle: formatClock(g.elapsed),
          ),
        ),
        if (_showResult) ...[
          Positioned.fill(
            child: ColoredBox(color: s.scrim.withValues(alpha: 0.35)),
          ),
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: _resultPanel(g),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoBar(SudokuGame g) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(levelIcon(g.level), size: 18, color: s.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _daily ? 'Hôm nay · ${g.level.label}' : g.level.label,
                  style: t.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.close_rounded,
                size: 18,
                color: g.mistakes > 0 ? s.error : s.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('mis-${g.mistakes}'),
                  tween: Tween(begin: g.mistakes > 0 ? 1.4 : 1, end: 1),
                  duration: _reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Text(
                    g.mistakeLimit
                        ? 'Lỗi ${g.mistakes}/${SudokuGame.maxMistakes}'
                        : 'Lỗi ${g.mistakes}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelLarge?.copyWith(
                      color: g.mistakes > 0 ? s.error : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: ValueListenableBuilder<int>(
                  valueListenable: _clock,
                  builder: (_, v, _) => Text(
                    formatClock(v),
                    key: const ValueKey('sudoku-clock'),
                    maxLines: 1,
                    style: t.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: _paused ? 'Tiếp tục' : 'Tạm dừng',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                onPressed: g.isOver ? null : _togglePause,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pauseCover() {
    final s = Theme.of(context).colorScheme;
    return AspectRatio(
      key: const ValueKey('pause'),
      aspectRatio: 1,
      child: Material(
        color: s.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _togglePause,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pause_circle_outline, size: 72, color: s.primary),
              const SizedBox(height: 8),
              Text('Tạm dừng', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _togglePause,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Tiếp tục'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hintCard(ColorScheme s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: PopIn(
      trigger: _hintText,
      child: Material(
        color: s.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.lightbulb, color: s.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _hintText!,
                  style: TextStyle(color: s.onTertiaryContainer),
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                onPressed: () => setState(_clearHint),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _resultPanel(SudokuGame g) {
    final won = g.isWon;
    final String title;
    if (won) {
      title = _daily
          ? 'Xong thử thách hôm nay!'
          : 'Hoàn thành ${g.level.label}!';
    } else {
      title = 'Hết lượt sai';
    }
    return SudokuResultPanel(
      won: won,
      seconds: g.elapsed,
      mistakes: g.mistakes,
      mistakeLimit: g.mistakeLimit,
      hints: g.hintsUsed,
      best: won && !_daily ? _best : null,
      newRecord: won && _newRecord,
      title: title,
      actions: [
        if (!won)
          OutlinedButton(
            onPressed: _continueWithoutLimit,
            child: const Text('Chơi tiếp, bỏ giới hạn'),
          ),
        if (!won)
          OutlinedButton(
            onPressed: _restartSame,
            child: const Text('Chơi lại đề này'),
          ),
        FilledButton(
          key: const ValueKey('sudoku-result-next'),
          onPressed: _daily
              ? () => context.go(_store.homeRoute)
              : _backToPicker,
          child: Text(_daily ? 'Về thử thách' : 'Ván mới'),
        ),
      ],
    );
  }
}
