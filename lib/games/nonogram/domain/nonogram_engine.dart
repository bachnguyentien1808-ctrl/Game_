import 'dart:math';

export 'package:puzzle_hub/games/nonogram/domain/puzzles.dart';

/// Day so goi y cua mot hang/cot (vd '#.##' -> [1, 2]).
List<int> clueOf(List<bool> line) {
  final out = <int>[];
  var run = 0;
  for (final f in line) {
    if (f) {
      run++;
    } else if (run > 0) {
      out.add(run);
      run = 0;
    }
  }
  if (run > 0) out.add(run);
  return out.isEmpty ? [0] : out;
}

class NonogramPuzzle {
  NonogramPuzzle(List<String> rows)
    : solution = [
        for (final r in rows) [for (final ch in r.split('')) ch == '#'],
      ];

  final List<List<bool>> solution;

  int get size => solution.length;

  List<List<int>> get rowClues => [for (final r in solution) clueOf(r)];

  List<List<int>> get colClues => [
    for (var c = 0; c < size; c++)
      clueOf([for (var r = 0; r < size; r++) solution[r][c]]),
  ];

  /// grid: 0 trong, 1 to, 2 danh dau X. Dung khi moi o 'to' khop dap an.
  bool isSolved(List<List<int>> grid) {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if ((grid[r][c] == 1) != solution[r][c]) return false;
      }
    }
    return true;
  }
}

/// Mot thay doi cua mot o (de hoan tac).
typedef CellChange = ({int r, int c, int from, int to});

/// Cong cu to: to o hoac danh dau X.
const int toolFill = 1;
const int toolMark = 2;

/// Mot van nonogram: luoi, hoan tac/lam lai, goi y, dem loi.
class NonogramGame {
  NonogramGame(this.puzzle, {List<List<int>>? grid, this.maxHints = 3})
    : grid =
          grid ??
          List.generate(puzzle.size, (_) => List.filled(puzzle.size, 0));

  final NonogramPuzzle puzzle;
  final List<List<int>> grid;
  final int maxHints;

  /// O da lo bang goi y (khong sua duoc).
  final Set<int> locked = {};
  int hintsUsed = 0;
  int mistakes = 0;

  final List<List<CellChange>> _undo = [];
  final List<List<CellChange>> _redo = [];
  List<CellChange>? _stroke;

  int get size => puzzle.size;

  bool get isSolved => puzzle.isSolved(grid);
  bool get isBlank => grid.every((row) => row.every((v) => v == 0));
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get hintsLeft => maxHints - hintsUsed;

  int _id(int r, int c) => r * size + c;

  /// Gia tri dich cua mot net keo bat dau tai o (r,c) voi cong cu [tool]:
  /// cung loai thi xoa (0), nguoc lai dat [tool].
  int strokeTarget(int r, int c, int tool) => grid[r][c] == tool ? 0 : tool;

  void beginStroke() => _stroke = [];

  /// Ap dung [target] cho o (r,c) trong net dang keo. true neu o doi.
  /// Dat (to/X) chi ghi len o trong; xoa chi xoa o cung loai cong cu.
  bool paint(int r, int c, int target, int tool) {
    final stroke = _stroke;
    if (stroke == null || locked.contains(_id(r, c))) return false;
    final cur = grid[r][c];
    if (target == 0 ? cur != tool : cur != 0) return false;
    grid[r][c] = target;
    stroke.add((r: r, c: c, from: cur, to: target));
    if (target == 1 && !puzzle.solution[r][c]) mistakes++;
    return true;
  }

  /// Ket thuc net keo; true neu net co thay doi (da vao lich su).
  bool endStroke() {
    final s = _stroke;
    _stroke = null;
    if (s == null || s.isEmpty) return false;
    _undo.add(s);
    _redo.clear();
    return true;
  }

  /// Cham/keo nhanh mot o: tien ich cho test.
  bool tapCell(int r, int c, int tool) {
    beginStroke();
    paint(r, c, strokeTarget(r, c, tool), tool);
    return endStroke();
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    final s = _undo.removeLast();
    for (final ch in s.reversed) {
      grid[ch.r][ch.c] = ch.from;
    }
    _redo.add(s);
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    final s = _redo.removeLast();
    for (final ch in s) {
      grid[ch.r][ch.c] = ch.to;
    }
    _undo.add(s);
    return true;
  }

  /// Xoa sach luoi va lich su.
  void clear() {
    for (final row in grid) {
      row.fillRange(0, row.length, 0);
    }
    locked.clear();
    _undo.clear();
    _redo.clear();
    hintsUsed = 0;
    mistakes = 0;
  }

  /// Lo mot o dung. null neu het luot hoac da dung het.
  (int, int)? hint(Random rng) {
    if (hintsLeft <= 0) return null;
    final wrong = <(int, int)>[
      for (var r = 0; r < size; r++)
        for (var c = 0; c < size; c++)
          if (!locked.contains(_id(r, c)) &&
              (grid[r][c] == 1) != puzzle.solution[r][c])
            (r, c),
    ];
    if (wrong.isEmpty) return null;
    final (r, c) = wrong[rng.nextInt(wrong.length)];
    // chi lo o 'to' dung; o thua thi xoa va lo la X
    grid[r][c] = puzzle.solution[r][c] ? 1 : 2;
    locked.add(_id(r, c));
    hintsUsed++;
    return (r, c);
  }

  bool isLocked(int r, int c) => locked.contains(_id(r, c));

  List<bool> _rowFilled(int r) => [
    for (var c = 0; c < size; c++) grid[r][c] == 1,
  ];
  List<bool> _colFilled(int c) => [
    for (var r = 0; r < size; r++) grid[r][c] == 1,
  ];

  /// Hang r da du goi y (day o to hien tai khop goi y).
  bool rowDone(int r) => _same(clueOf(_rowFilled(r)), puzzle.rowClues[r]);
  bool colDone(int c) => _same(clueOf(_colFilled(c)), puzzle.colClues[c]);

  /// O 'to' sai (khong thuoc tranh).
  bool isWrongCell(int r, int c) => grid[r][c] == 1 && !puzzle.solution[r][c];

  bool rowHasError(int r) =>
      [for (var c = 0; c < size; c++) isWrongCell(r, c)].any((e) => e);
  bool colHasError(int c) =>
      [for (var r = 0; r < size; r++) isWrongCell(r, c)].any((e) => e);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Thoi gian chuan (giay) de duoc du 3 sao.
  int get parSeconds => (size * size * 2.5).round();

  /// Sao 1..3 theo thoi gian va so loi/goi y.
  int starsFor(int seconds) {
    var s = 3;
    if (seconds > parSeconds) s--;
    if (mistakes > 3 || hintsUsed > 1) s--;
    return s.clamp(1, 3);
  }
}
