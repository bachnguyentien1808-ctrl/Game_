import 'dart:math';

/// Tat den: bam mot o se dao trang thai o do va 4 o lang gieng.
class LightsOut {
  LightsOut(this.cells, {this.moves = 0});

  /// Sinh de giai duoc bang cach bam ngau nhien tu bang tat het.
  factory LightsOut.generate({int size = 5, Random? rng}) {
    final r = rng ?? Random();
    LightsOut g;
    do {
      g = LightsOut(List.generate(size, (_) => List.filled(size, false)));
      for (var i = 0; i < size * 2; i++) {
        g.press(r.nextInt(size), r.nextInt(size), count: false);
      }
    } while (g.solved);
    return g;
  }

  factory LightsOut.fromJson(Map<String, dynamic> j) => LightsOut([
    for (final r in j['cells'] as List) (r as List).cast<bool>().toList(),
  ], moves: j['moves'] as int);

  final List<List<bool>> cells;
  int moves;

  int get size => cells.length;

  bool get solved => cells.every((r) => r.every((v) => !v));

  Map<String, dynamic> toJson() => {'cells': cells, 'moves': moves};

  void press(int r, int c, {bool count = true}) {
    for (final (dr, dc) in const [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
        cells[nr][nc] = !cells[nr][nc];
      }
    }
    if (count) moves++;
  }
}
