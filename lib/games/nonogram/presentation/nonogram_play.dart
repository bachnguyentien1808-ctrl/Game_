import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/core/ui/glass.dart';
import 'package:puzzle_hub/core/ui/score_chip.dart';
import 'package:puzzle_hub/features/common/game_block.dart';
import 'package:puzzle_hub/features/common/hub_panels.dart';
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
    this.onAward,
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

  /// Goi khi thang de cong diem (game id nonogram) - tuy chon.
  final Future<int> Function(int points)? onAward;

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
  int? _points;

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final Set<int> _burstRows = {};
  final Set<int> _burstCols = {};
  int _toastId = 0;
  String _toastText = '';
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
    _burst.dispose();
    super.dispose();
  }

  bool get _anim => !MediaQuery.disableAnimationsOf(context);

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
    final doneRows = _flashRows.toList()..sort();
    final doneCols = _flashCols.toList()..sort();
    if (doneRows.isNotEmpty || doneCols.isNotEmpty) {
      Sfx.play(SfxKind.match);
      GameFx.success();
      if (!_g.isSolved) _announceLines(doneRows, doneCols);
    }
    if ((_flashRows.isNotEmpty || _flashCols.isNotEmpty) && _anim) {
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

  /// Chum sao chay doc hang/cot vua xong + bong bong "Hang 4 xong!".
  void _announceLines(List<int> rows, List<int> cols) {
    if (!_anim) return;
    final parts = [
      if (rows.isNotEmpty) 'Hàng ${rows.map((e) => e + 1).join(', ')}',
      if (cols.isNotEmpty) 'Cột ${cols.map((e) => e + 1).join(', ')}',
    ];
    _burstRows
      ..clear()
      ..addAll(rows);
    _burstCols
      ..clear()
      ..addAll(cols);
    _toastId++;
    _toastText = '${parts.join(' và ')} xong!';
    _burst.forward(from: 0).whenComplete(() {
      _burstRows.clear();
      _burstCols.clear();
    });
  }

  void _win() {
    _won = true;
    _stars = _g.starsFor(_seconds);
    GameFx.success();
    Sfx.play(SfxKind.win);
    final pts = Scoring.points(
      base: 600,
      seconds: _seconds,
      parSeconds: _g.size * 50,
      mult: max(0.6, _g.size / 5),
      mistakes: _g.mistakes,
      hints: _g.hintsUsed,
    );
    _points = pts;
    widget.onAward?.call(pts);
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
      _points = null;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CandyBackground(
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
                  constraints: const BoxConstraints(
                    maxWidth: 1000,
                    maxHeight: 920,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
                    child: GameBlock(
                      actions: [
                        Tooltip(
                          message: 'Hoàn tác',
                          child: CandyButton(
                            dim: !(_g.canUndo && !_won),
                            circle: true,
                            padding: const EdgeInsets.all(7),
                            onPressed: _g.canUndo && !_won ? _undo : null,
                            child: const Icon(Icons.undo, size: 24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Làm lại bước',
                          child: CandyButton(
                            colors: Candy.indigo,
                            dim: !(_g.canRedo && !_won),
                            circle: true,
                            padding: const EdgeInsets.all(7),
                            onPressed: _g.canRedo && !_won ? _redo : null,
                            child: const Icon(Icons.redo, size: 24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Ván mới',
                          child: CandyButton(
                            colors: Candy.green,
                            circle: true,
                            padding: const EdgeInsets.all(7),
                            onPressed: _restart,
                            child: const Icon(Icons.refresh_rounded, size: 24),
                          ),
                        ),
                      ],
                      expand: true,
                      title: '${_pic.name} ${_n}x$_n',
                      onBack: _back,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                            child: GlassBar(
                              children: [
                                GlassStat(
                                  icon: Icons.timer_outlined,
                                  text: formatSeconds(_seconds),
                                ),
                                GlassStat(
                                  icon: Icons.close_rounded,
                                  colors: Candy.red,
                                  text: '${_g.mistakes}',
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(child: _board(context)),
                                if (_toastText.isNotEmpty)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: IgnorePointer(
                                      child: _LineToast(
                                        key: ValueKey(_toastId),
                                        text: _toastText,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                            child: GlassPanel(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      _toolButton(
                                        NonogramTool.fill,
                                        Icons.square_rounded,
                                        'Tô',
                                        Candy.purple,
                                      ),
                                      const SizedBox(width: 8),
                                      _toolButton(
                                        NonogramTool.mark,
                                        Icons.close,
                                        'X',
                                        Candy.red,
                                      ),
                                      const SizedBox(width: 8),
                                      _toolButton(
                                        NonogramTool.move,
                                        Icons.open_with,
                                        'Xem',
                                        Candy.teal,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CandyButton(
                                        onPressed: () =>
                                            setState(() => _check = !_check),
                                        colors: Candy.green,
                                        dim: !_check,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 7,
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.rule, size: 16),
                                            SizedBox(width: 4),
                                            Text('Kiểm lỗi'),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Tooltip(
                                        message: 'Gợi ý: lộ một ô đúng',
                                        child: CandyButton(
                                          onPressed: _g.hintsLeft > 0 && !_won
                                              ? _hint
                                              : null,
                                          colors: Candy.orange,
                                          dim: !(_g.hintsLeft > 0 && !_won),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.lightbulb_outline,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text('${_g.hintsLeft}'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
                  show: _banner,
                  points: _points,
                  title: 'Hoàn thành!',
                  subtitle:
                      '${_pic.name} · ${formatSeconds(_seconds)} · ${'★' * _stars}${'☆' * (3 - _stars)}',
                  onAgain: _back,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolButton(
    NonogramTool tool,
    IconData icon,
    String label,
    List<Color> colors,
  ) {
    return Expanded(
      child: CandyButton(
        onPressed: () => setState(() => _tool = tool),
        colors: colors,
        dim: _tool != tool,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _board(BuildContext context) {
    final rowClues = _g.puzzle.rowClues;
    final colClues = _g.puzzle.colClues;
    final maxCol = colClues.fold<int>(1, (m, e) => max(m, e.length));
    // Do rong that cua goi y hang (theo don vi co chu): chu so + khoang trang.
    final rowUnits = rowClues.fold<double>(1, (m, e) {
      final digits = e.fold<int>(0, (a, v) => a + '$v'.length);
      return max(m, digits * 0.58 + (e.length - 1) * 0.3);
    });
    return LayoutBuilder(
      builder: (context, box) {
        final availW = box.maxWidth - 16;
        final availH = box.maxHeight - 16;
        // Goi y khong con chua thua cho: luoi + goi y sat nhau, can giua o.
        var cell = min(
          (availW - 14) / (_n + rowUnits * 0.46),
          (availH - 10) / (_n + maxCol * 0.46 * 1.15),
        );
        cell = cell.clamp(18.0, 120.0);
        final fs = cell * 0.46;
        final clueW = rowUnits * fs + 14;
        final clueH = maxCol * fs * 1.15 + 10;

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

        final content = CandyFrame(
          padding: 6,
          child: SizedBox(
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
                              child: _clue(
                                colClues[c],
                                vertical: true,
                                done: _g.colDone(c),
                                err: _check && _g.colHasError(c),
                                hot: _hotC == c,
                                fs: fs,
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
                              child: _clue(
                                rowClues[r],
                                vertical: false,
                                done: _g.rowDone(r),
                                err: _check && _g.rowHasError(r),
                                hot: _hotR == r,
                                fs: fs,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(left: clueW, top: clueH, child: grid),
                Positioned(
                  left: clueW,
                  top: clueH,
                  width: _n * cell,
                  height: _n * cell,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _burst,
                      builder: (_, _) => CustomPaint(
                        painter: _LineBurstPainter(
                          _burst.value,
                          cell,
                          {
                            for (final r in _burstRows)
                              for (var c = 0; c < _n; c++) (r, c),
                            for (final c in _burstCols)
                              for (var r = 0; r < _n; r++) (r, c),
                          }.toList(),
                          _burstRows,
                          _burstCols,
                          _n,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

  static const _clueColors = [
    Color(0xFF7FE3FF),
    Color(0xFFFFD166),
    Color(0xFFFF9EC8),
    Color(0xFFB4F27A),
  ];

  /// Goi y mot hang/cot: moi so mot mau; xong thi mo di, loi thi do.
  Widget _clue(
    List<int> clue, {
    required bool vertical,
    required bool done,
    required bool err,
    required bool hot,
    required double fs,
  }) {
    Color colorOf(int k) => err
        ? const Color(0xFFFF6B6B)
        : done
        ? Colors.white.withValues(alpha: 0.28)
        : hot
        ? Colors.white
        : _clueColors[k % _clueColors.length];
    final weight = hot ? FontWeight.w900 : FontWeight.w800;
    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var k = 0; k < clue.length; k++)
            Text(
              '${clue[k]}',
              style: TextStyle(
                fontSize: fs,
                height: 1.15,
                fontWeight: weight,
                color: colorOf(k),
              ),
            ),
        ],
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          for (var k = 0; k < clue.length; k++)
            TextSpan(
              text: k == 0 ? '${clue[k]}' : ' ${clue[k]}',
              style: TextStyle(color: colorOf(k)),
            ),
        ],
      ),
      softWrap: false,
      style: TextStyle(fontSize: fs, fontWeight: weight, height: 1.1),
    );
  }

  Widget _cellWidget(int r, int c, double cell) {
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
    final fillTop = Color.lerp(
      const Color(0xFF9DB8FF),
      Color.alphaBlend(Colors.white24, picColor),
      ease,
    )!;
    final fillBottom = Color.lerp(const Color(0xFF6A5CF0), picColor, ease)!;

    var bg = (r + c).isEven ? const Color(0xFFE4EFFF) : const Color(0xFFD3E4FA);
    if (hot && !_won) bg = Color.alphaBlend(const Color(0x553D8BFF), bg);
    if (wrong) bg = Color.alphaBlend(const Color(0xAAFF3B30), bg);
    if (flashing) {
      bg = Color.alphaBlend(
        const Color(0xFFFFD166).withValues(alpha: 0.7 * (1 - _flash.value)),
        bg,
      );
    }
    final borderAlpha = 1 - ease;
    BorderSide side({required bool thick}) => BorderSide(
      color: (thick ? const Color(0xFFBFD4FF) : const Color(0xFF173B52))
          .withValues(alpha: thick ? 0.55 * borderAlpha : borderAlpha),
      width: thick ? 1.6 : 0.8,
    );
    final thickR = (c + 1) % 5 == 0 && c < n - 1;
    final thickB = (r + 1) % 5 == 0 && r < n - 1;
    final dur = _anim ? const Duration(milliseconds: 180) : Duration.zero;
    return Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        border: Border(
          right: side(thick: thickR),
          bottom: side(thick: thickB),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_won ? 2 : 5),
          border: Border(
            top: BorderSide(
              color: Colors.black.withValues(alpha: 0.28 * borderAlpha),
              width: 1.5,
            ),
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_won ? 2 : 5),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [fillTop, fillBottom],
                  ),
                  boxShadow: _won
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x66000000),
                            offset: Offset(0, 1.5),
                          ),
                        ],
                ),
                child: _won
                    ? null
                    : const Stack(children: [CandyGloss(radius: 4)]),
              ),
            ),
            AnimatedOpacity(
              opacity: v == 2 && !_won ? 1 : 0,
              duration: dur,
              child: Icon(
                _g.isLocked(r, c) ? Icons.lightbulb : Icons.close,
                size: cell * 0.62,
                color: _g.isLocked(r, c)
                    ? const Color(0xFFF0A020)
                    : const Color(0xFFE0475B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Song sao toa ra doc cac o cua hang/cot vua xong (khong de lai dau).
class _LineBurstPainter extends CustomPainter {
  const _LineBurstPainter(
    this.t,
    this.cell,
    this.cells,
    this.rows,
    this.cols,
    this.n,
  );

  final double t;
  final double cell;
  final List<(int, int)> cells;
  final Set<int> rows;
  final Set<int> cols;
  final int n;

  static const _colors = [
    Color(0xFFFFEB3B),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFFF80AB),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    for (final (r, c) in cells) {
      // song: o xa diem bat dau hon thi no tre hon
      final pos = rows.contains(r) ? c : r;
      final lt = ((t - (pos / max(1, n - 1)) * .45) / .55).clamp(0.0, 1.0);
      if (lt <= 0 || lt >= 1) continue;
      _burstAt(canvas, Offset((c + .5) * cell, (r + .5) * cell), lt);
    }
  }

  void _burstAt(Canvas canvas, Offset center, double lt) {
    final e = Curves.easeOutCubic.transform(lt);
    final fade = (1 - lt).clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      cell * (.3 + .5 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * fade + 1
        ..color = const Color(0xFF2EC27E).withValues(alpha: fade),
    );
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + .3;
      final p = center + Offset(cos(a), sin(a)) * (cell * (.3 + .6 * e));
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

  @override
  bool shouldRepaint(_LineBurstPainter old) => old.t != t;
}

/// Bong bong xanh noi len roi mo dan khi xong hang/cot.
class _LineToast extends StatelessWidget {
  const _LineToast({required this.text, super.key});

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
                  fontSize: 16,
                  shadows: [Shadow(color: Color(0x88000000), blurRadius: 2)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
