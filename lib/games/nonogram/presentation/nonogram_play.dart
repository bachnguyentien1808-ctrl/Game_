import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/games/nonogram/domain/nonogram_engine.dart';

/// Che do thao tac: to o, danh dau X, hoac di chuyen/phong to.
enum NonogramTool { fill, mark, move }

String formatSeconds(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

/// Man choi mot tranh nonogram.
class NonogramPlay extends StatefulWidget {
  const NonogramPlay({
    required this.index,
    required this.game,
    required this.initialSeconds,
    required this.onSave,
    required this.onFirstMove,
    required this.onSolved,
    required this.onBack,
    super.key,
  });

  final int index;
  final NonogramGame game;
  final int initialSeconds;

  /// Luu van dang do (goi sau moi net to va khi thoat).
  final void Function(int seconds) onSave;
  final VoidCallback onFirstMove;

  /// Goi dung mot lan khi giai xong: (giay, sao).
  final void Function(int seconds, int stars) onSolved;
  final VoidCallback onBack;

  @override
  State<NonogramPlay> createState() => _NonogramPlayState();
}

class _NonogramPlayState extends State<NonogramPlay>
    with TickerProviderStateMixin {
  late final NonogramGame _g = widget.game;
  late final NonogramPicture _pic = nonogramPuzzles[widget.index];
  late int _seconds = widget.initialSeconds;
  Timer? _timer;

  NonogramTool _tool = NonogramTool.fill;
  bool _check = false;
  bool _banner = false;
  bool _won = false;
  int _stars = 0;

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  final Set<int> _flashRows = {};
  final Set<int> _flashCols = {};

  final Random _rng = Random();

  // net keo
  late int _startR;
  late int _startC;
  late int _lastR;
  late int _lastC;
  int? _axis; // 0 hang, 1 cot
  int _target = 0;
  int? _hotR;
  int? _hotC;
  bool _strokeActive = false;
  bool _wasBlankAtStart = false;

  int get _n => _g.size;

  @override
  void initState() {
    super.initState();
    _won = _g.isSolved && !_g.isBlank;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _won) return;
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flash.dispose();
    _reveal.dispose();
    super.dispose();
  }

  bool get _anim => !MediaQuery.of(context).disableAnimations;

  // ---------- nhap lieu ----------

  (int, int) _cellAt(Offset p, double cell) => (
    (p.dy / cell).floor().clamp(0, _n - 1),
    (p.dx / cell).floor().clamp(0, _n - 1),
  );

  int get _toolValue => _tool == NonogramTool.fill ? toolFill : toolMark;

  void _down(PointerDownEvent e, double cell) {
    if (_tool == NonogramTool.move || _won) return;
    final (r, c) = _cellAt(e.localPosition, cell);
    _wasBlankAtStart = _g.isBlank;
    _beforeRows = [for (var i = 0; i < _n; i++) _g.rowDone(i)];
    _beforeCols = [for (var i = 0; i < _n; i++) _g.colDone(i)];
    _g.beginStroke();
    _strokeActive = true;
    _startR = _lastR = r;
    _startC = _lastC = c;
    _axis = null;
    _target = _g.strokeTarget(r, c, _toolValue);
    setState(() {
      _hotR = r;
      _hotC = c;
      _paintCell(r, c);
    });
  }

  List<bool> _beforeRows = const [];
  List<bool> _beforeCols = const [];

  void _paintCell(int r, int c) {
    if (_g.paint(r, c, _target, _toolValue)) {
      GameFx.tap();
      Sfx.play(_target == 0 ? SfxKind.erase : SfxKind.place);
      if (_target == 1 && !_g.puzzle.solution[r][c] && _check) {
        GameFx.error();
        Sfx.play(SfxKind.error);
      }
    }
  }

  void _move(PointerMoveEvent e, double cell) {
    if (!_strokeActive) return;
    var (r, c) = _cellAt(e.localPosition, cell);
    final sr = _startR;
    final sc = _startC;
    if (_axis == null && (r != sr || c != sc)) {
      _axis = (r - sr).abs() >= (c - sc).abs() ? 1 : 0;
    }
    if (_axis == 0) r = sr;
    if (_axis == 1) c = sc;
    if (r == _lastR && c == _lastC) return;
    setState(() {
      // lap tu o truoc den o hien tai de khong bo sot khi keo nhanh
      var cr = _lastR;
      var cc = _lastC;
      while (cr != r || cc != c) {
        if (cr != r) cr += r > cr ? 1 : -1;
        if (cc != c) cc += c > cc ? 1 : -1;
        _paintCell(cr, cc);
      }
      _lastR = r;
      _lastC = c;
      _hotR = r;
      _hotC = c;
    });
  }

  void _up() {
    if (!_strokeActive) return;
    _strokeActive = false;
    final changed = _g.endStroke();
    setState(() {
      _hotR = _hotC = null;
    });
    if (changed) _afterChange();
  }

  void _afterChange({bool silent = false}) {
    if (_wasBlankAtStart && !silent) widget.onFirstMove();
    _wasBlankAtStart = false;
    // hang/cot vua hoan thanh -> chop sang
    for (var i = 0; i < _n; i++) {
      if (_beforeRows.length > i && !_beforeRows[i] && _g.rowDone(i)) {
        _flashRows.add(i);
      }
      if (_beforeCols.length > i && !_beforeCols[i] && _g.colDone(i)) {
        _flashCols.add(i);
      }
    }
    if ((_flashRows.isNotEmpty || _flashCols.isNotEmpty) && _anim) {
      Sfx.play(SfxKind.match);
      _flash.forward(from: 0).whenComplete(() {
        _flashRows.clear();
        _flashCols.clear();
      });
    } else {
      _flashRows.clear();
      _flashCols.clear();
    }
    if (_g.isSolved && !_won) {
      _win();
    } else {
      widget.onSave(_seconds);
    }
    setState(() {});
  }

  void _win() {
    _won = true;
    _stars = _g.starsFor(_seconds);
    GameFx.success();
    Sfx.play(SfxKind.win);
    widget.onSolved(_seconds, _stars);
    if (_anim) {
      _reveal.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _banner = true);
      });
    } else {
      _reveal.value = 1;
      _banner = true;
    }
  }

  void _undo() {
    if (_won || !_g.undo()) return;
    Sfx.play(SfxKind.erase);
    setState(() {});
    widget.onSave(_seconds);
  }

  void _redo() {
    if (_won || !_g.redo()) return;
    Sfx.play(SfxKind.place);
    setState(() {});
    _beforeRows = [for (var i = 0; i < _n; i++) _g.rowDone(i)];
    _beforeCols = [for (var i = 0; i < _n; i++) _g.colDone(i)];
    if (_g.isSolved) {
      _win();
      setState(() {});
    } else {
      widget.onSave(_seconds);
    }
  }

  void _hint() {
    if (_won) return;
    _beforeRows = [for (var i = 0; i < _n; i++) _g.rowDone(i)];
    _beforeCols = [for (var i = 0; i < _n; i++) _g.colDone(i)];
    final h = _g.hint(_rng);
    if (h == null) return;
    GameFx.success();
    Sfx.play(SfxKind.success);
    _afterChange(silent: true);
  }

  void _restart() {
    setState(() {
      _g.clear();
      _seconds = 0;
      _won = false;
      _banner = false;
      _reveal.value = 0;
    });
    widget.onSave(0);
  }

  void _back() {
    widget.onSave(_seconds);
    widget.onBack();
  }

  // ---------- giao dien ----------

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _back),
          title: Text('${_pic.name} ${_n}x$_n'),
          actions: [
            IconButton(
              tooltip: 'Hoàn tác',
              icon: const Icon(Icons.undo),
              onPressed: _g.canUndo && !_won ? _undo : null,
            ),
            IconButton(
              tooltip: 'Làm lại bước',
              icon: const Icon(Icons.redo),
              onPressed: _g.canRedo && !_won ? _redo : null,
            ),
            IconButton(
              tooltip: 'Bắt đầu lại',
              icon: const Icon(Icons.refresh),
              onPressed: _restart,
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 18, color: s.outline),
                      const SizedBox(width: 4),
                      Text(formatSeconds(_seconds), style: t.titleMedium),
                      const Spacer(),
                      FilterChip(
                        avatar: const Icon(Icons.rule, size: 18),
                        label: const Text('Kiểm lỗi'),
                        visualDensity: VisualDensity.compact,
                        selected: _check,
                        onSelected: (v) => setState(() => _check = v),
                      ),
                      const SizedBox(width: 4),
                      ActionChip(
                        avatar: const Icon(Icons.lightbulb_outline, size: 18),
                        label: Text('${_g.hintsLeft}'),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Gợi ý: lộ một ô đúng',
                        onPressed: _g.hintsLeft > 0 && !_won ? _hint : null,
                      ),
                    ],
                  ),
                ),
                Expanded(child: _board(context)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SegmentedButton<NonogramTool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: NonogramTool.fill,
                        icon: Icon(Icons.square_rounded),
                        label: Text('Tô'),
                      ),
                      ButtonSegment(
                        value: NonogramTool.mark,
                        icon: Icon(Icons.close),
                        label: Text('X'),
                      ),
                      ButtonSegment(
                        value: NonogramTool.move,
                        icon: Icon(Icons.open_with),
                        label: Text('Xem'),
                      ),
                    ],
                    selected: {_tool},
                    onSelectionChanged: (v) => setState(() => _tool = v.first),
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: WinBanner(
                show: _banner,
                title: 'Hoàn thành!',
                subtitle:
                    '${_pic.name} · ${formatSeconds(_seconds)} · ${'★' * _stars}${'☆' * (3 - _stars)}',
                onAgain: _back,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _board(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final rowClues = _g.puzzle.rowClues;
    final colClues = _g.puzzle.colClues;
    final maxRow = rowClues.fold<int>(1, (m, e) => max(m, e.length));
    final maxCol = colClues.fold<int>(1, (m, e) => max(m, e.length));
    return LayoutBuilder(
      builder: (context, box) {
        final availW = box.maxWidth - 16;
        final availH = box.maxHeight - 16;
        var cell = min(
          (availW - 6) / (_n + maxRow * 0.62),
          (availH - 6) / (_n + maxCol * 0.9),
        );
        cell = cell.clamp(18.0, 44.0);
        final clueW = maxRow * cell * 0.62 + 6;
        final clueH = maxCol * cell * 0.9 + 6;
        final fs = cell * 0.46;

        Widget clueText(
          List<int> clue, {
          required bool done,
          required bool err,
          required bool hot,
        }) {
          final color = err
              ? s.error
              : done
              ? s.outline.withValues(alpha: 0.4)
              : hot
              ? s.primary
              : s.onSurface;
          return DefaultTextStyle(
            style: TextStyle(
              fontSize: fs,
              fontWeight: hot ? FontWeight.w800 : FontWeight.w600,
              color: color,
              height: 1.1,
            ),
            child: Text(clue.join(' ')),
          );
        }

        final grid = Listener(
          key: const ValueKey('nono-grid'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _down(e, cell),
          onPointerMove: (e) => _move(e, cell),
          onPointerUp: (_) => _up(),
          onPointerCancel: (_) => _up(),
          child: AnimatedBuilder(
            animation: Listenable.merge([_flash, _reveal]),
            builder: (context, _) => Column(
              children: [
                for (var r = 0; r < _n; r++)
                  Row(
                    children: [
                      for (var c = 0; c < _n; c++) _cellWidget(r, c, cell),
                    ],
                  ),
              ],
            ),
          ),
        );

        final content = SizedBox(
          width: clueW + _n * cell,
          height: clueH + _n * cell,
          child: Stack(
            children: [
              // goi y cot
              Positioned(
                left: clueW,
                top: 0,
                height: clueH,
                child: Row(
                  children: [
                    for (var c = 0; c < _n; c++)
                      SizedBox(
                        width: cell,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: _stack(
                              colClues[c],
                              done: _g.colDone(c),
                              err: _check && _g.colHasError(c),
                              hot: _hotC == c,
                              fs: fs,
                              s: s,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // goi y hang
              Positioned(
                left: 0,
                top: clueH,
                width: clueW,
                child: Column(
                  children: [
                    for (var r = 0; r < _n; r++)
                      SizedBox(
                        height: cell,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: clueText(
                              rowClues[r],
                              done: _g.rowDone(r),
                              err: _check && _g.rowHasError(r),
                              hot: _hotR == r,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(left: clueW, top: clueH, child: grid),
            ],
          ),
        );

        final move = _tool == NonogramTool.move;
        return Padding(
          padding: const EdgeInsets.all(8),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 3.5,
            panEnabled: move,
            scaleEnabled: move,
            boundaryMargin: const EdgeInsets.all(120),
            child: Center(child: content),
          ),
        );
      },
    );
  }

  /// Goi y cot: moi so mot dong.
  Widget _stack(
    List<int> clue, {
    required bool done,
    required bool err,
    required bool hot,
    required double fs,
    required ColorScheme s,
  }) {
    final color = err
        ? s.error
        : done
        ? s.outline.withValues(alpha: 0.4)
        : hot
        ? s.primary
        : s.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final v in clue)
          Text(
            '$v',
            style: TextStyle(
              fontSize: fs,
              height: 1.15,
              fontWeight: hot ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
      ],
    );
  }

  Widget _cellWidget(int r, int c, double cell) {
    final s = Theme.of(context).colorScheme;
    final v = _g.grid[r][c];
    final n = _n;
    final hot = _hotR == r || _hotC == c;
    final wrong = _check && _g.isWrongCell(r, c);
    final flashing = _flashRows.contains(r) || _flashCols.contains(c);

    // dot song khi thang: tung hang chuyen mau lech nhau
    final rt = ((_reveal.value * 1.6) - (r / n) * 0.6).clamp(0.0, 1.0);
    final ease = Curves.easeInOut.transform(rt);
    final picColor = Color.lerp(
      Color(_pic.top),
      Color(_pic.bottom),
      n == 1 ? 0 : r / (n - 1),
    )!;
    final fillColor = Color.lerp(s.primary, picColor, ease)!;

    var bg = s.surface;
    if (hot && !_won) {
      bg = Color.alphaBlend(s.primary.withValues(alpha: 0.10), bg);
    }
    if (wrong) bg = Color.alphaBlend(s.error.withValues(alpha: 0.28), bg);
    if (flashing) {
      bg = Color.alphaBlend(
        s.tertiary.withValues(alpha: 0.55 * (1 - _flash.value)),
        bg,
      );
    }
    final borderAlpha = 1 - ease;
    BorderSide side({required bool thick}) => BorderSide(
      color: (thick ? s.outline : s.outlineVariant).withValues(
        alpha: borderAlpha,
      ),
      width: thick ? 1.6 : 0.8,
    );
    final thickR = (c + 1) % 5 == 0 && c < n - 1;
    final thickB = (r + 1) % 5 == 0 && r < n - 1;
    final dur = _anim ? const Duration(milliseconds: 180) : Duration.zero;
    return Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          right: side(thick: thickR),
          bottom: side(thick: thickB),
          left: c == 0 ? side(thick: true) : BorderSide.none,
          top: r == 0 ? side(thick: true) : BorderSide.none,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedScale(
            scale: v == 1 ? 1 : 0,
            duration: dur,
            curve: Curves.easeOutBack,
            child: Container(
              margin: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(_won ? 1 : 4),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: v == 2 && !_won ? 1 : 0,
            duration: dur,
            child: Icon(
              _g.isLocked(r, c) ? Icons.lightbulb : Icons.close,
              size: cell * 0.5,
              color: s.outline,
            ),
          ),
        ],
      ),
    );
  }
}
