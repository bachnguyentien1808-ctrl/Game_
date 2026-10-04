import 'dart:math';

import 'package:puzzle_hub/games/sudoku/domain/sudoku_solver.dart';

/// Bang Sudoku 9x9, 0 = o trong.
typedef Grid = List<List<int>>;

/// Muc do kho. [holes] = so o bo trong muc tieu.
enum SudokuLevel {
  easy('Dễ', 38),
  medium('Vừa', 46),
  hard('Khó', 52),
  expert('Chuyên gia', 58);

  SudokuLevel(this.label, this.holes);

  final String label;
  final int holes;

  /// Khoa thong ke rieng cho muc nay (vd 'sudoku.easy').
  String get statsId => 'sudoku.$name';

  static SudokuLevel byName(String? n) => SudokuLevel.values.firstWhere(
    (l) => l.name == n,
    orElse: () => SudokuLevel.medium,
  );
}

const _all = 0x3FE; // bit 1..9

int _bitCount(int m) {
  var n = 0;
  var x = m;
  while (x != 0) {
    x &= x - 1;
    n++;
  }
  return n;
}

/// Tim kiem bitmask + chon o it ung vien nhat (MRV). Lam viec tren mang 81 o.
class _Search {
  _Search(this.cells) {
    for (var i = 0; i < 81; i++) {
      final v = cells[i];
      if (v == 0) continue;
      final b = 1 << v;
      final r = i ~/ 9;
      final c = i % 9;
      final x = r ~/ 3 * 3 + c ~/ 3;
      if ((rows[r] | cols[c] | boxes[x]) & b != 0) valid = false;
      rows[r] |= b;
      cols[c] |= b;
      boxes[x] |= b;
    }
  }

  final List<int> cells;
  final rows = List<int>.filled(9, 0);
  final cols = List<int>.filled(9, 0);
  final boxes = List<int>.filled(9, 0);
  bool valid = true;

  /// Dem loi giai, dung khi dat [limit].
  int count(int limit) {
    var best = -1;
    var bestMask = 0;
    var bestN = 10;
    for (var i = 0; i < 81; i++) {
      if (cells[i] != 0) continue;
      final r = i ~/ 9;
      final c = i % 9;
      final m = ~(rows[r] | cols[c] | boxes[r ~/ 3 * 3 + c ~/ 3]) & _all;
      final n = _bitCount(m);
      if (n == 0) return 0;
      if (n < bestN) {
        best = i;
        bestMask = m;
        bestN = n;
        if (n == 1) break;
      }
    }
    if (best < 0) return 1;
    var total = 0;
    for (var v = 1; v <= 9; v++) {
      if (bestMask & (1 << v) == 0) continue;
      _set(best, v);
      total += count(limit - total);
      _unset(best, v);
      if (total >= limit) return total;
    }
    return total;
  }

  /// Giai (ghi vao [cells]); [rng] tron thu tu thu so.
  bool solve(Random? rng) {
    var best = -1;
    var bestMask = 0;
    var bestN = 10;
    for (var i = 0; i < 81; i++) {
      if (cells[i] != 0) continue;
      final r = i ~/ 9;
      final c = i % 9;
      final m = ~(rows[r] | cols[c] | boxes[r ~/ 3 * 3 + c ~/ 3]) & _all;
      final n = _bitCount(m);
      if (n == 0) return false;
      if (n < bestN) {
        best = i;
        bestMask = m;
        bestN = n;
        if (n == 1) break;
      }
    }
    if (best < 0) return true;
    final nums = [
      for (var v = 1; v <= 9; v++)
        if (bestMask & (1 << v) != 0) v,
    ];
    if (rng != null) nums.shuffle(rng);
    for (final v in nums) {
      _set(best, v);
      if (solve(rng)) return true;
      _unset(best, v);
    }
    return false;
  }

  void _set(int i, int v) {
    final b = 1 << v;
    final r = i ~/ 9;
    final c = i % 9;
    cells[i] = v;
    rows[r] |= b;
    cols[c] |= b;
    boxes[r ~/ 3 * 3 + c ~/ 3] |= b;
  }

  void _unset(int i, int v) {
    final b = ~(1 << v);
    final r = i ~/ 9;
    final c = i % 9;
    cells[i] = 0;
    rows[r] &= b;
    cols[c] &= b;
    boxes[r ~/ 3 * 3 + c ~/ 3] &= b;
  }
}

abstract final class SudokuEngine {
  static Grid empty() => List.generate(9, (_) => List.filled(9, 0));

  static Grid copy(Grid g) => [for (final r in g) List<int>.of(r)];

  static List<int> flatten(Grid g) => [for (final r in g) ...r];

  static Grid unflatten(List<int> f) => [
    for (var r = 0; r < 9; r++) f.sublist(r * 9, r * 9 + 9),
  ];

  static bool canPlace(Grid g, int r, int c, int v) {
    for (var i = 0; i < 9; i++) {
      if (g[r][i] == v || g[i][c] == v) return false;
    }
    final br = r ~/ 3 * 3;
    final bc = c ~/ 3 * 3;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        if (g[br + i][bc + j] == v) return false;
      }
    }
    return true;
  }

  /// Giai; tra ve true neu co loi giai (ghi vao g).
  static bool solve(Grid g, {Random? rng}) {
    final s = _Search(flatten(g));
    if (!s.valid || !s.solve(rng)) return false;
    for (var i = 0; i < 81; i++) {
      g[i ~/ 9][i % 9] = s.cells[i];
    }
    return true;
  }

  /// Dem so loi giai, dung som khi dat [limit].
  static int countSolutions(Grid g, {int limit = 2}) =>
      countFlat(flatten(g), limit: limit);

  static int countFlat(List<int> cells, {int limit = 2}) {
    final s = _Search(List<int>.of(cells));
    return s.valid ? s.count(limit) : 0;
  }

  /// Sinh de co loi giai duy nhat voi khoang [holes] o trong.
  static ({Grid puzzle, Grid solution}) generate({
    int holes = 45,
    Random? rng,
  }) {
    final r = rng ?? Random();
    final sol = _Search(List<int>.filled(81, 0))..solve(r);
    final solution = List<int>.of(sol.cells);
    final puzzle = _dig(solution, holes, r);
    return (puzzle: unflatten(puzzle), solution: unflatten(solution));
  }

  static List<int> _dig(List<int> solution, int holes, Random r) {
    final puzzle = List<int>.of(solution);
    final order = [for (var i = 0; i < 81; i++) i]..shuffle(r);
    var removed = 0;
    for (final i in order) {
      if (removed >= holes) break;
      final keep = puzzle[i];
      puzzle[i] = 0;
      if (countFlat(puzzle) != 1) {
        puzzle[i] = keep;
      } else {
        removed++;
      }
    }
    return puzzle;
  }

  /// So lan thu toi da khi tim de dung muc do kho (giu thoi gian sinh thap).
  static const maxAttempts = 24;

  /// Sinh de theo muc [level], cham bang bo giai ky thuat. Cung [seed] cho
  /// cung de tren moi may. Thu toi da [maxAttempts] lan, giu de gan nhat.
  static ({List<int> puzzle, List<int> solution}) generateLevel(
    SudokuLevel level, {
    int? seed,
  }) {
    final r = Random(seed ?? Random().nextInt(1 << 31));
    ({List<int> puzzle, List<int> solution})? fallback;
    var fallbackDist = 99;
    for (var a = 0; a < maxAttempts; a++) {
      final sol = _Search(List<int>.filled(81, 0))..solve(r);
      final solution = List<int>.of(sol.cells);
      final puzzle = _dig(solution, level.holes, r);
      final got = SudokuSolver.rate(puzzle);
      final res = (puzzle: puzzle, solution: solution);
      if (got == level) return res;
      // De du phong: muc gan nhat voi muc yeu cau.
      final d = (got.index - level.index).abs();
      if (d < fallbackDist) {
        fallback = res;
        fallbackDist = d;
      }
    }
    return fallback!;
  }
}
