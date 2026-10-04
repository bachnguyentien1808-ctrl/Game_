import 'dart:math';

class MineCell {
  bool mine = false;
  bool open = false;
  bool flag = false;
  int near = 0;
}

class Minesweeper {
  Minesweeper({this.rows = 9, this.cols = 9, this.mines = 10})
    : cells = List.generate(
        rows,
        (_) => List.generate(cols, (_) => MineCell()),
      );

  /// Khoi phuc tu JSON; so mine lang gieng duoc tinh lai.
  factory Minesweeper.fromJson(Map<String, dynamic> j) {
    final bits = (j['bits'] as List)
        .map((r) => (r as List).cast<int>())
        .toList();
    final g = Minesweeper(
      rows: bits.length,
      cols: bits.first.length,
      mines: j['mines'] as int,
    );
    for (var r = 0; r < g.rows; r++) {
      for (var c = 0; c < g.cols; c++) {
        final v = bits[r][c];
        g.cells[r][c]
          ..mine = v & 1 != 0
          ..open = v & 2 != 0
          ..flag = v & 4 != 0;
      }
    }
    g
      ..placed = j['placed'] as bool
      ..lost = j['lost'] as bool
      .._countNear();
    return g;
  }

  final int rows;
  final int cols;
  final int mines;
  final List<List<MineCell>> cells;
  bool placed = false;
  bool lost = false;

  Map<String, dynamic> toJson() => {
    'mines': mines,
    'placed': placed,
    'lost': lost,
    'bits': [
      for (final row in cells)
        [
          for (final c in row)
            (c.mine ? 1 : 0) | (c.open ? 2 : 0) | (c.flag ? 4 : 0),
        ],
    ],
  };

  bool get won =>
      placed &&
      !lost &&
      cells.every((row) => row.every((c) => c.mine || c.open));

  bool get over => lost || won;

  int get flagsLeft =>
      mines - cells.fold(0, (a, row) => a + row.where((c) => c.flag).length);

  Iterable<(int, int)> _neighbors(int r, int c) sync* {
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr;
        final nc = c + dc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) yield (nr, nc);
      }
    }
  }

  void _countNear() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        cells[r][c].near = _neighbors(
          r,
          c,
        ).where((p) => cells[p.$1][p.$2].mine).length;
      }
    }
  }

  /// Dat mine sau luot mo dau tien, tranh o (r,c) va lang gieng.
  void _place(int r, int c, Random rng) {
    final banned = {(r, c), ..._neighbors(r, c)};
    final spots = <(int, int)>[
      for (var i = 0; i < rows; i++)
        for (var j = 0; j < cols; j++)
          if (!banned.contains((i, j))) (i, j),
    ]..shuffle(rng);
    for (final p in spots.take(mines)) {
      cells[p.$1][p.$2].mine = true;
    }
    _countNear();
    placed = true;
  }

  void open(int r, int c, {Random? rng}) {
    if (over) return;
    final cell = cells[r][c];
    if (cell.flag || cell.open) return;
    if (!placed) _place(r, c, rng ?? Random());
    if (cell.mine) {
      lost = true;
      return;
    }
    final stack = [(r, c)];
    while (stack.isNotEmpty) {
      final (cr, cc) = stack.removeLast();
      final cur = cells[cr][cc];
      if (cur.open || cur.flag) continue;
      cur.open = true;
      if (cur.near == 0) stack.addAll(_neighbors(cr, cc));
    }
  }

  void toggleFlag(int r, int c) {
    if (over) return;
    final cell = cells[r][c];
    if (cell.open) return;
    cell.flag = !cell.flag;
  }
}
