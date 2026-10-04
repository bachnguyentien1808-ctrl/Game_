import 'dart:math';

/// Mot doan lien (run) cac o trang theo hang ngang hoac cot doc.
class KakuroRun {
  const KakuroRun({
    required this.across,
    required this.clueRow,
    required this.clueCol,
    required this.sum,
    required this.cells,
  });

  /// true = doan ngang (goi y o goc tren-phai cua o den),
  /// false = doan doc (goi y o goc duoi-trai).
  final bool across;
  final int clueRow;
  final int clueCol;
  final int sum;
  final List<(int, int)> cells;

  int get length => cells.length;
}

/// De Kakuro: luoi size x size (size = n + 1), hang 0 va cot 0 luon den.
/// [solution] = 0 o o den, 1-9 o o trang.
class KakuroPuzzle {
  KakuroPuzzle._(this.size, this.solution)
    : white = [
        for (final row in solution) [for (final v in row) v != 0],
      ] {
    _buildRuns();
  }

  /// Tao tu loi giai co san (dung cho test va fromJson).
  factory KakuroPuzzle.fromSolution(List<List<int>> solution) {
    final size = solution.length;
    if (size < 3 || solution.any((r) => r.length != size)) {
      throw const FormatException('Luoi Kakuro khong hop le');
    }
    for (var i = 0; i < size; i++) {
      if (solution[0][i] != 0 || solution[i][0] != 0) {
        throw const FormatException('Hang 0 va cot 0 phai la o den');
      }
    }
    for (final r in solution) {
      for (final v in r) {
        if (v < 0 || v > 9) throw const FormatException('Chu so sai');
      }
    }
    return KakuroPuzzle._(size, [
      for (final r in solution) [...r],
    ]);
  }

  factory KakuroPuzzle.fromJson(Map<String, dynamic> j) {
    final s = j['s']! as List;
    return KakuroPuzzle.fromSolution([
      for (final r in s) (r as List).cast<int>().toList(),
    ]);
  }

  final int size;
  final List<List<int>> solution;
  final List<List<bool>> white;

  /// Goi y tong ngang/doc tai o den (0 = khong co).
  late final List<List<int>> across = List.generate(
    size,
    (_) => List.filled(size, 0),
  );
  late final List<List<int>> down = List.generate(
    size,
    (_) => List.filled(size, 0),
  );
  final List<KakuroRun> runs = [];

  /// Chi so doan ngang/doc chua o (r, c) trong [runs] (-1 neu o den).
  late final List<List<int>> acrossRunOf = List.generate(
    size,
    (_) => List.filled(size, -1),
  );
  late final List<List<int>> downRunOf = List.generate(
    size,
    (_) => List.filled(size, -1),
  );

  Map<String, dynamic> toJson() => {'s': solution};

  int get whiteCount => white.expand((r) => r).where((w) => w).length;

  bool isWhite(int r, int c) => white[r][c];

  void _buildRuns() {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (white[r][c]) continue;
        // doan ngang ben phai
        final h = <(int, int)>[];
        for (var k = c + 1; k < size && white[r][k]; k++) {
          h.add((r, k));
        }
        if (h.isNotEmpty) {
          final sum = h.fold(0, (a, p) => a + solution[p.$1][p.$2]);
          across[r][c] = sum;
          for (final p in h) {
            acrossRunOf[p.$1][p.$2] = runs.length;
          }
          runs.add(
            KakuroRun(across: true, clueRow: r, clueCol: c, sum: sum, cells: h),
          );
        }
        // doan doc ben duoi
        final v = <(int, int)>[];
        for (var k = r + 1; k < size && white[k][c]; k++) {
          v.add((k, c));
        }
        if (v.isNotEmpty) {
          final sum = v.fold(0, (a, p) => a + solution[p.$1][p.$2]);
          down[r][c] = sum;
          for (final p in v) {
            downRunOf[p.$1][p.$2] = runs.length;
          }
          runs.add(
            KakuroRun(
              across: false,
              clueRow: r,
              clueCol: c,
              sum: sum,
              cells: v,
            ),
          );
        }
      }
    }
  }

  /// Luoi nguoi choi rong (0 o moi o).
  List<List<int>> emptyGrid() =>
      List.generate(size, (_) => List.filled(size, 0));

  /// Doan [run] da du o, khong trung va dung tong.
  bool runSolved(List<List<int>> grid, KakuroRun run) {
    final seen = <int>{};
    var sum = 0;
    for (final (r, c) in run.cells) {
      final v = grid[r][c];
      if (v < 1 || v > 9 || !seen.add(v)) return false;
      sum += v;
    }
    return sum == run.sum;
  }

  /// Thang khi MOI doan hop le (khong can trung loi giai sinh ra).
  bool isSolved(List<List<int>> grid) =>
      runs.every((run) => runSolved(grid, run));

  /// Cac o loi: trung chu so trong doan, tong da dien vuot goi y,
  /// hoac doan da du o ma sai tong.
  Set<(int, int)> errors(List<List<int>> grid) {
    final out = <(int, int)>{};
    for (final run in runs) {
      final byDigit = <int, List<(int, int)>>{};
      var sum = 0;
      var filled = 0;
      for (final p in run.cells) {
        final v = grid[p.$1][p.$2];
        if (v == 0) continue;
        filled++;
        sum += v;
        (byDigit[v] ??= []).add(p);
      }
      for (final cells in byDigit.values) {
        if (cells.length > 1) out.addAll(cells);
      }
      final over = sum > run.sum;
      final wrongFull = filled == run.length && sum != run.sum;
      if (over || wrongFull) {
        for (final p in run.cells) {
          if (grid[p.$1][p.$2] != 0) out.add(p);
        }
      }
    }
    return out;
  }

  /// Sinh de ngau nhien. [n] = so hang/cot o choi (5-7), [density] = ty le
  /// o trang ban dau. Tat dinh voi cung [rng] seed.
  static KakuroPuzzle generate({
    int n = 6,
    double density = 0.75,
    Random? rng,
    int maxAttempts = 2000,
  }) {
    final r = rng ?? Random();
    final size = n + 1;
    final minWhite = (n * n * 0.45).ceil();
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final layout = _layout(size, density, r);
      final count = layout.expand((x) => x).where((w) => w).length;
      if (count < minWhite) continue;
      final sol = _fill(layout, r, 4000);
      if (sol != null) return KakuroPuzzle._(size, sol);
    }
    throw StateError('Khong sinh duoc de Kakuro');
  }

  /// Bo cuc: o trang ngau nhien, roi lap chuyen den moi o trang co doan
  /// ngang hoac doc ngan hon 2 cho toi khi on dinh.
  static List<List<bool>> _layout(int size, double p, Random rng) {
    final w = List.generate(
      size,
      (r) => List.generate(size, (c) => r > 0 && c > 0 && rng.nextDouble() < p),
    );
    var changed = true;
    while (changed) {
      changed = false;
      for (var r = 1; r < size; r++) {
        for (var c = 1; c < size; c++) {
          if (!w[r][c]) continue;
          if (_runLen(w, r, c, 0, 1) < 2 || _runLen(w, r, c, 1, 0) < 2) {
            w[r][c] = false;
            changed = true;
          }
        }
      }
    }
    return w;
  }

  static int _runLen(List<List<bool>> w, int r, int c, int dr, int dc) {
    final size = w.length;
    var len = 1;
    var rr = r - dr;
    var cc = c - dc;
    while (rr >= 0 && cc >= 0 && w[rr][cc]) {
      len++;
      rr -= dr;
      cc -= dc;
    }
    rr = r + dr;
    cc = c + dc;
    while (rr < size && cc < size && w[rr][cc]) {
      len++;
      rr += dr;
      cc += dc;
    }
    return len;
  }

  /// Dien loi giai bang quay lui, chu so xao ngau nhien, gioi han so buoc.
  static List<List<int>>? _fill(List<List<bool>> w, Random rng, int limit) {
    final size = w.length;
    final g = List.generate(size, (_) => List.filled(size, 0));
    final cells = <(int, int)>[
      for (var r = 0; r < size; r++)
        for (var c = 0; c < size; c++)
          if (w[r][c]) (r, c),
    ];
    var steps = 0;
    bool used(int r, int c, int v) {
      for (var k = c - 1; k >= 0 && w[r][k]; k--) {
        if (g[r][k] == v) return true;
      }
      for (var k = c + 1; k < size && w[r][k]; k++) {
        if (g[r][k] == v) return true;
      }
      for (var k = r - 1; k >= 0 && w[k][c]; k--) {
        if (g[k][c] == v) return true;
      }
      for (var k = r + 1; k < size && w[k][c]; k++) {
        if (g[k][c] == v) return true;
      }
      return false;
    }

    bool go(int i) {
      if (i == cells.length) return true;
      if (++steps > limit) return false;
      final (r, c) = cells[i];
      final digits = [for (var d = 1; d <= 9; d++) d]..shuffle(rng);
      for (final d in digits) {
        if (used(r, c, d)) continue;
        g[r][c] = d;
        if (go(i + 1)) return true;
        if (steps > limit) return false;
      }
      g[r][c] = 0;
      return false;
    }

    return go(0) ? g : null;
  }
}
