import 'dart:math';

/// Bang Sudoku 9x9, 0 = o trong.
typedef Grid = List<List<int>>;

abstract final class SudokuEngine {
  static Grid empty() => List.generate(9, (_) => List.filled(9, 0));

  static Grid copy(Grid g) => [for (final r in g) List<int>.of(r)];

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

  /// Giai bang backtracking; tra ve true neu co loi giai (ghi vao g).
  static bool solve(Grid g, {Random? rng}) {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (g[r][c] != 0) continue;
        final nums = [1, 2, 3, 4, 5, 6, 7, 8, 9];
        if (rng != null) nums.shuffle(rng);
        for (final v in nums) {
          if (canPlace(g, r, c, v)) {
            g[r][c] = v;
            if (solve(g, rng: rng)) return true;
            g[r][c] = 0;
          }
        }
        return false;
      }
    }
    return true;
  }

  /// Dem so loi giai, dung som khi vuot [limit].
  static int countSolutions(Grid g, {int limit = 2}) {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (g[r][c] != 0) continue;
        var n = 0;
        for (var v = 1; v <= 9; v++) {
          if (!canPlace(g, r, c, v)) continue;
          g[r][c] = v;
          n += countSolutions(g, limit: limit - n);
          g[r][c] = 0;
          if (n >= limit) return n;
        }
        return n;
      }
    }
    return 1;
  }

  /// Sinh de co loi giai duy nhat. [holes] = so o bo trong (do kho).
  static ({Grid puzzle, Grid solution}) generate({
    int holes = 45,
    Random? rng,
  }) {
    final r = rng ?? Random();
    final solution = empty();
    solve(solution, rng: r);
    final puzzle = copy(solution);
    final cells = [for (var i = 0; i < 81; i++) i]..shuffle(r);
    var removed = 0;
    for (final i in cells) {
      if (removed >= holes) break;
      final row = i ~/ 9;
      final col = i % 9;
      final keep = puzzle[row][col];
      puzzle[row][col] = 0;
      if (countSolutions(copy(puzzle)) != 1) {
        puzzle[row][col] = keep;
      } else {
        removed++;
      }
    }
    return (puzzle: puzzle, solution: solution);
  }
}
