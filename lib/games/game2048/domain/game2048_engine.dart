import 'dart:math';

enum Dir { left, right, up, down }

class Board2048 {
  Board2048(this.cells, {this.score = 0});

  factory Board2048.start({Random? rng}) {
    final b = Board2048(List.generate(4, (_) => List.filled(4, 0)));
    b
      ..spawn(rng ?? Random())
      ..spawn(rng ?? Random());
    return b;
  }

  final List<List<int>> cells;
  int score;

  Board2048 copy() =>
      Board2048([for (final r in cells) List.of(r)], score: score);

  void spawn(Random rng) {
    final empty = <(int, int)>[
      for (var r = 0; r < 4; r++)
        for (var c = 0; c < 4; c++)
          if (cells[r][c] == 0) (r, c),
    ];
    if (empty.isEmpty) return;
    final (r, c) = empty[rng.nextInt(empty.length)];
    cells[r][c] = rng.nextDouble() < 0.9 ? 2 : 4;
  }

  /// Tron mot hang ve ben trai, tra ve hang moi va diem cong them.
  static (List<int>, int) _slide(List<int> line) {
    final nums = line.where((v) => v != 0).toList();
    final out = <int>[];
    var gain = 0;
    for (var i = 0; i < nums.length; i++) {
      if (i + 1 < nums.length && nums[i] == nums[i + 1]) {
        out.add(nums[i] * 2);
        gain += nums[i] * 2;
        i++;
      } else {
        out.add(nums[i]);
      }
    }
    while (out.length < 4) {
      out.add(0);
    }
    return (out, gain);
  }

  /// Di chuyen; tra ve true neu ban co thay doi.
  bool move(Dir d) {
    var changed = false;
    for (var i = 0; i < 4; i++) {
      final line = [
        for (var j = 0; j < 4; j++)
          switch (d) {
            Dir.left => cells[i][j],
            Dir.right => cells[i][3 - j],
            Dir.up => cells[j][i],
            Dir.down => cells[3 - j][i],
          },
      ];
      final (res, gain) = _slide(line);
      score += gain;
      for (var j = 0; j < 4; j++) {
        final (r, c) = switch (d) {
          Dir.left => (i, j),
          Dir.right => (i, 3 - j),
          Dir.up => (j, i),
          Dir.down => (3 - j, i),
        };
        if (cells[r][c] != res[j]) changed = true;
        cells[r][c] = res[j];
      }
    }
    return changed;
  }

  bool get canMove {
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        if (cells[r][c] == 0) return true;
        if (c < 3 && cells[r][c] == cells[r][c + 1]) return true;
        if (r < 3 && cells[r][c] == cells[r + 1][c]) return true;
      }
    }
    return false;
  }

  bool get reached2048 => cells.any((r) => r.any((v) => v >= 2048));
}
