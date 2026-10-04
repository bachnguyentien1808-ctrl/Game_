import 'dart:math';

/// Huong vuot: o ke o trong se truot THEO huong nay.
enum SlideDir { up, down, left, right }

/// Xep so: truot cac o ve vi tri 1..n*n-1, o trong (0) o cuoi.
/// Ho tro 3x3, 4x4, 5x5, hoan tac nhieu buoc, goi y nuoc di ke.
class SlidingPuzzle {
  SlidingPuzzle(this.tiles, {this.size = 4, this.moves = 0, List<int>? history})
    : history = history ?? <int>[];

  /// Sinh bang cach tron ngau nhien tu bang da giai: luon giai duoc (parity),
  /// khong bao gio da giai san va khong qua gan dich.
  factory SlidingPuzzle.generate({int size = 4, Random? rng}) {
    final r = rng ?? Random();
    final steps = size * size * 18 + 40;
    while (true) {
      final g = SlidingPuzzle([
        for (var i = 1; i < size * size; i++) i,
        0,
      ], size: size);
      var last = -1;
      for (var i = 0; i < steps; i++) {
        final blank = g.tiles.indexOf(0);
        final opts = g._adjacent(blank).where((p) => p != last).toList();
        final pick = opts[r.nextInt(opts.length)];
        last = blank;
        g._swap(blank, pick);
      }
      if (!g.solved && g.distance >= size * 2) return g;
    }
  }

  factory SlidingPuzzle.fromJson(Map<String, dynamic> j) {
    final size = j['size'] as int;
    final tiles = (j['tiles'] as List).cast<int>().toList();
    if (size < 2 || tiles.length != size * size) {
      throw const FormatException('Bang khong hop le');
    }
    if (tiles.toSet().length != tiles.length ||
        tiles.any((t) => t < 0 || t >= tiles.length)) {
      throw const FormatException('Bang khong hop le');
    }
    final hist = ((j['history'] as List?) ?? const <int>[])
        .cast<int>()
        .where((p) => p >= 0 && p < tiles.length)
        .toList();
    return SlidingPuzzle(
      tiles,
      size: size,
      moves: j['moves'] as int,
      history: hist,
    );
  }

  /// Bang co giai duoc khong (theo parity cua hoan vi + hang o trong).
  static bool isSolvable(List<int> tiles, int size) {
    var inv = 0;
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i] == 0) continue;
      for (var j = i + 1; j < tiles.length; j++) {
        if (tiles[j] != 0 && tiles[i] > tiles[j]) inv++;
      }
    }
    if (size.isOdd) return inv.isEven;
    final blankRowFromBottom = size - tiles.indexOf(0) ~/ size;
    return blankRowFromBottom.isOdd ? inv.isEven : inv.isOdd;
  }

  final List<int> tiles;
  final int size;
  int moves;

  /// Vi tri o trong truoc moi nuoc di (de hoan tac).
  final List<int> history;

  Map<String, dynamic> toJson() => {
    'tiles': tiles,
    'size': size,
    'moves': moves,
    'history': history.length > 300
        ? history.sublist(history.length - 300)
        : history,
  };

  bool get solved {
    for (var i = 0; i < tiles.length - 1; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return tiles.last == 0;
  }

  bool get canUndo => history.isNotEmpty;

  int get blank => tiles.indexOf(0);

  /// Uoc luong so buoc con lai (Manhattan + linear conflict).
  int get distance => _heuristic(tiles, size);

  List<int> _adjacent(int i) {
    final r = i ~/ size;
    final c = i % size;
    return [
      if (r > 0) i - size,
      if (r < size - 1) i + size,
      if (c > 0) i - 1,
      if (c < size - 1) i + 1,
    ];
  }

  void _swap(int a, int b) {
    final t = tiles[a];
    tiles[a] = tiles[b];
    tiles[b] = t;
  }

  /// Truot chuoi o tu [index] ve o trong; tra ve true neu cung hang/cot.
  bool _slideChain(int index) {
    final blank = tiles.indexOf(0);
    if (index == blank) return false;
    final br = blank ~/ size;
    final bc = blank % size;
    final r = index ~/ size;
    final c = index % size;
    if (r != br && c != bc) return false;
    final step = r == br ? (c > bc ? 1 : -1) : (r > br ? size : -size);
    var cur = blank;
    while (cur != index) {
      _swap(cur, cur + step);
      cur += step;
    }
    return true;
  }

  /// Bam o [index]: truot ca hang/cot ve phia o trong neu cung hang hoac cot.
  bool tap(int index) {
    if (index < 0 || index >= tiles.length) return false;
    final before = tiles.indexOf(0);
    if (!_slideChain(index)) return false;
    history.add(before);
    moves++;
    return true;
  }

  /// Vuot theo huong [dir]: o ke o trong truot theo huong do.
  bool slide(SlideDir dir) {
    final b = tiles.indexOf(0);
    final br = b ~/ size;
    final bc = b % size;
    var sr = br;
    var sc = bc;
    switch (dir) {
      case SlideDir.up:
        sr = br + 1;
      case SlideDir.down:
        sr = br - 1;
      case SlideDir.left:
        sc = bc + 1;
      case SlideDir.right:
        sc = bc - 1;
    }
    if (sr < 0 || sr >= size || sc < 0 || sc >= size) return false;
    return tap(sr * size + sc);
  }

  /// Hoan tac mot nuoc di. Tra ve false neu khong con gi de hoan tac.
  bool undo() {
    if (history.isEmpty) return false;
    final prevBlank = history.removeLast();
    _slideChain(prevBlank);
    if (moves > 0) moves--;
    return true;
  }

  /// Goi y: vi tri o nen bam ke tiep (mot buoc don). 3x3 la nuoc toi uu.
  /// null neu da giai.
  int? hint() {
    if (solved) return null;
    final path = solve(maxNodes: size <= 3 ? 4000000 : 60000);
    if (path != null && path.isNotEmpty) return path.first;
    return _greedyHint();
  }

  /// Chuoi vi tri can bam de giai (moi phan tu la mot buoc don), hoac null
  /// neu vuot gioi han [maxNodes] (IDA*).
  List<int>? solve({int maxNodes = 200000}) {
    if (solved) return const [];
    if (!isSolvable(tiles, size)) return null;
    final t = List<int>.of(tiles);
    final n = size;
    var bound = _heuristic(t, n);
    final path = <int>[];
    var nodes = 0;
    var aborted = false;

    int search(int g, int blank, int prev, int h) {
      final f = g + h;
      if (f > bound) return f;
      if (h == 0) return -1;
      var minNext = 1 << 30;
      final r = blank ~/ n;
      final c = blank % n;
      for (var k = 0; k < 4; k++) {
        int p;
        switch (k) {
          case 0:
            if (r == 0) continue;
            p = blank - n;
          case 1:
            if (r == n - 1) continue;
            p = blank + n;
          case 2:
            if (c == 0) continue;
            p = blank - 1;
          default:
            if (c == n - 1) continue;
            p = blank + 1;
        }
        if (p == prev) continue;
        if (++nodes > maxNodes) {
          aborted = true;
          return 1 << 30;
        }
        t[blank] = t[p];
        t[p] = 0;
        path.add(p);
        final res = search(g + 1, p, blank, _heuristic(t, n));
        if (res == -1) return -1;
        path.removeLast();
        t[p] = t[blank];
        t[blank] = 0;
        if (aborted) return 1 << 30;
        if (res < minNext) minNext = res;
      }
      return minNext;
    }

    final start = t.indexOf(0);
    while (true) {
      final res = search(0, start, -1, _heuristic(t, n));
      if (res == -1) return List<int>.of(path);
      if (aborted || res >= 1 << 30) return null;
      bound = res;
    }
  }

  /// Du phong cho bang lon: nhin truoc vai buoc, chon nuoc giam heuristic.
  int? _greedyHint() {
    final b = tiles.indexOf(0);
    final forbid = history.isNotEmpty ? history.last : -1;
    final t = List<int>.of(tiles);
    var best = -1;
    var bestScore = 1 << 30;
    int look(int depth, int blank, int prev) {
      if (depth == 0) return _heuristic(t, size);
      var m = 1 << 30;
      for (final p in _adjacent(blank)) {
        if (p == prev) continue;
        t[blank] = t[p];
        t[p] = 0;
        final v = look(depth - 1, p, blank);
        t[p] = t[blank];
        t[blank] = 0;
        if (v < m) m = v;
      }
      return m;
    }

    final opts = _adjacent(b);
    for (final p in opts) {
      if (p == forbid && opts.length > 1) continue;
      t[b] = t[p];
      t[p] = 0;
      final v = look(5, p, b) + 1;
      t[p] = t[b];
      t[b] = 0;
      if (v < bestScore) {
        bestScore = v;
        best = p;
      }
    }
    return best < 0 ? null : best;
  }

  /// Manhattan + linear conflict (cho phep cho bang n x n bat ky).
  static int _heuristic(List<int> t, int n) {
    var md = 0;
    for (var i = 0; i < t.length; i++) {
      final v = t[i];
      if (v == 0) continue;
      final g = v - 1;
      md += ((i ~/ n) - (g ~/ n)).abs() + ((i % n) - (g % n)).abs();
    }
    return md +
        2 *
            (_conflictRemovals(t, n, rows: true) +
                _conflictRemovals(t, n, rows: false));
  }

  static int _conflictRemovals(List<int> t, int n, {required bool rows}) {
    var total = 0;
    for (var line = 0; line < n; line++) {
      // Cac o thuoc dung hang/cot dich cua no, theo thu tu vi tri.
      final goals = <int>[];
      for (var k = 0; k < n; k++) {
        final idx = rows ? line * n + k : k * n + line;
        final v = t[idx];
        if (v == 0) continue;
        final g = v - 1;
        final goalLine = rows ? g ~/ n : g % n;
        if (goalLine != line) continue;
        goals.add(rows ? g % n : g ~/ n);
      }
      if (goals.length < 2) continue;
      final m = goals.length;
      final conf = List<int>.filled(m, 0);
      for (var i = 0; i < m; i++) {
        for (var j = i + 1; j < m; j++) {
          if (goals[i] > goals[j]) {
            conf[i]++;
            conf[j]++;
          }
        }
      }
      var removed = 0;
      while (true) {
        var worst = -1;
        var worstVal = 0;
        for (var i = 0; i < m; i++) {
          if (conf[i] > worstVal) {
            worstVal = conf[i];
            worst = i;
          }
        }
        if (worst < 0) break;
        removed++;
        for (var j = 0; j < m; j++) {
          if (j == worst) continue;
          final inConflict = worst < j
              ? goals[worst] > goals[j]
              : goals[j] > goals[worst];
          if (inConflict && conf[j] > 0) conf[j]--;
        }
        conf[worst] = 0;
      }
      total += removed;
    }
    return total;
  }
}
