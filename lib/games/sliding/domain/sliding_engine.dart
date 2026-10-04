import 'dart:math';

/// Xep so: truot cac o ve vi tri 1..n*n-1, o trong (0) o cuoi.
class SlidingPuzzle {
  SlidingPuzzle(this.tiles, {this.size = 4, this.moves = 0});

  /// Sinh bang cach tron ngau nhien tu bang da giai, luon giai duoc.
  factory SlidingPuzzle.generate({int size = 4, Random? rng}) {
    final r = rng ?? Random();
    final g = SlidingPuzzle([
      for (var i = 1; i < size * size; i++) i,
      0,
    ], size: size);
    var last = -1;
    for (var i = 0; i < 300; i++) {
      final blank = g.tiles.indexOf(0);
      final opts = g._adjacent(blank).where((p) => p != last).toList();
      final pick = opts[r.nextInt(opts.length)];
      last = blank;
      g._swap(blank, pick);
    }
    if (g.solved) return SlidingPuzzle.generate(size: size, rng: r);
    return g;
  }

  factory SlidingPuzzle.fromJson(Map<String, dynamic> j) => SlidingPuzzle(
    (j['tiles'] as List).cast<int>().toList(),
    size: j['size'] as int,
    moves: j['moves'] as int,
  );

  final List<int> tiles;
  final int size;
  int moves;

  Map<String, dynamic> toJson() => {
    'tiles': tiles,
    'size': size,
    'moves': moves,
  };

  bool get solved {
    for (var i = 0; i < tiles.length - 1; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return tiles.last == 0;
  }

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

  /// Bam o [index]: truot ca hang/cot ve phia o trong neu cung hang hoac cot.
  bool tap(int index) {
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
    moves++;
    return true;
  }
}
