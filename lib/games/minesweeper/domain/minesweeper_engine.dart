import 'dart:math';

class MineCell {
  bool mine = false;
  bool open = false;
  bool flag = false;
  int near = 0;
}

/// Cac muc do kho. [custom] dung kich thuoc do nguoi choi chon.
enum MineLevel {
  easy('easy', 'Dễ', 9, 9, 10),
  medium('medium', 'Vừa', 16, 16, 40),
  hard('hard', 'Khó', 16, 30, 99),
  custom('custom', 'Tuỳ chỉnh', 9, 9, 10);

  MineLevel(this.key, this.label, this.rows, this.cols, this.mines);

  final String key;
  final String label;
  final int rows;
  final int cols;
  final int mines;

  /// Id thong ke rieng cho muc nay, vd 'minesweeper.easy'.
  String get statsId => 'minesweeper.$key';

  static MineLevel byKey(String? k) => MineLevel.values.firstWhere(
    (l) => l.key == k,
    orElse: () => MineLevel.easy,
  );
}

class Minesweeper {
  Minesweeper({
    this.rows = 9,
    this.cols = 9,
    this.mines = 10,
    this.noGuess = true,
  }) : cells = List.generate(
         rows,
         (_) => List.generate(cols, (_) => MineCell()),
       );

  /// Ban tuy chinh; nem [ArgumentError] neu cau hinh khong hop le.
  factory Minesweeper.custom(int rows, int cols, int mines) {
    final err = validateConfig(rows, cols, mines);
    if (err != null) throw ArgumentError(err);
    return Minesweeper(rows: rows, cols: cols, mines: mines);
  }

  /// Ban thu thach ngay: o khoi dau chon tu [rng], mine tranh vung quanh no,
  /// o do duoc mo san => cung seed cho cung ban tren moi may.
  factory Minesweeper.daily({
    required Random rng,
    int rows = 16,
    int cols = 16,
    int mines = 40,
  }) {
    final g = Minesweeper(rows: rows, cols: cols, mines: mines);
    final r = rng.nextInt(rows);
    final c = rng.nextInt(cols);
    g.open(r, c, rng: rng);
    return g;
  }

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

  static const minSide = 5;
  static const maxRows = 30;
  static const maxCols = 40;

  /// So mine toi da hop le: chua du 9 o an toan cho luot dau.
  static int maxMinesFor(int rows, int cols) => max(1, rows * cols - 9);

  /// Tra ve loi (tieng Viet) neu cau hinh khong hop le, null neu hop le.
  static String? validateConfig(int rows, int cols, int mines) {
    if (rows < minSide || rows > maxRows) {
      return 'Số hàng phải từ $minSide đến $maxRows';
    }
    if (cols < minSide || cols > maxCols) {
      return 'Số cột phải từ $minSide đến $maxCols';
    }
    if (mines < 1) return 'Cần ít nhất 1 mìn';
    if (mines > maxMinesFor(rows, cols)) {
      return 'Tối đa ${maxMinesFor(rows, cols)} mìn cho bàn $rows x $cols';
    }
    return null;
  }

  final int rows;
  final int cols;
  final int mines;
  final List<List<MineCell>> cells;
  bool placed = false;
  bool lost = false;

  /// O nguoi choi vua mo trung mine (khong luu).
  (int, int)? boom;

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

  /// Co sinh ban giai duoc bang suy luan (khong phai doan) hay khong.
  final bool noGuess;

  /// Dat mine sau luot mo dau tien, tranh o (r,c) va lang gieng. Neu [noGuess]
  /// thi thu lai nhieu lan de tim ban giai duoc bang suy luan tu o dau; het
  /// luot thu thi dung ban cuoi (van hop le, co the phai doan).
  void _place(int r, int c, Random rng) {
    final banned = {(r, c), ..._neighbors(r, c)};
    final spots = <int>[
      for (var i = 0; i < rows; i++)
        for (var j = 0; j < cols; j++)
          if (!banned.contains((i, j))) i * cols + j,
    ];
    final attempts = noGuess ? (rows * cols <= 100 ? 150 : 40) : 1;
    var layout = List<bool>.filled(rows * cols, false);
    for (var a = 0; a < attempts; a++) {
      spots.shuffle(rng);
      layout = List<bool>.filled(rows * cols, false);
      for (final i in spots.take(mines)) {
        layout[i] = true;
      }
      if (!noGuess || _solvable(layout, r, c)) break;
    }
    for (var i = 0; i < layout.length; i++) {
      cells[i ~/ cols][i % cols].mine = layout[i];
    }
    _countNear();
    placed = true;
  }

  /// Bang hien tai co giai duoc bang suy luan neu mo dau tai (r,c) khong.
  bool isLogicSolvable(int r, int c) => _solvable(
    [
      for (final row in cells)
        for (final cell in row) cell.mine,
    ],
    r,
    c,
  );

  /// Gia lap nguoi choi chi dung suy luan chac chan (so == so o ke chua mo,
  /// so == so mine da biet, va quan he tap con giua hai so ke nhau) bat dau
  /// tu viec mo (sr,sc). True neu mo het duoc moi o an toan.
  bool _solvable(List<bool> mine, int sr, int sc) {
    int idx(int r, int c) => r * cols + c;
    Iterable<int> around(int i) sync* {
      final r = i ~/ cols;
      final c = i % cols;
      for (final p in _neighbors(r, c)) {
        yield idx(p.$1, p.$2);
      }
    }

    final near = List<int>.generate(
      rows * cols,
      (i) => around(i).where((n) => mine[n]).length,
    );
    final open = List<bool>.filled(rows * cols, false);
    final known = List<bool>.filled(rows * cols, false);
    var left = rows * cols - mines;

    void flood(int start) {
      final stack = [start];
      while (stack.isNotEmpty) {
        final i = stack.removeLast();
        if (open[i] || known[i]) continue;
        open[i] = true;
        left--;
        if (near[i] == 0) stack.addAll(around(i));
      }
    }

    flood(idx(sr, sc));
    var progress = true;
    while (progress && left > 0) {
      progress = false;
      // Rang buoc: moi o so da mo con o chua ro xung quanh.
      final unk = <int, List<int>>{};
      final rem = <int, int>{};
      for (var i = 0; i < open.length; i++) {
        if (!open[i] || near[i] == 0) continue;
        final u = <int>[];
        var k = 0;
        for (final n in around(i)) {
          if (open[n]) continue;
          if (known[n]) {
            k++;
          } else {
            u.add(n);
          }
        }
        if (u.isEmpty) continue;
        unk[i] = u;
        rem[i] = near[i] - k;
      }
      void resolve(Iterable<int> cs, {required bool isMine}) {
        for (final n in cs.toList()) {
          if (open[n] || known[n]) continue;
          if (isMine) {
            known[n] = true;
          } else {
            flood(n);
          }
          progress = true;
        }
      }

      for (final e in unk.entries) {
        final m = rem[e.key]!;
        if (m == 0) {
          resolve(e.value, isMine: false);
        } else if (m == e.value.length) {
          resolve(e.value, isMine: true);
        }
      }
      if (progress) continue;
      // Luat tap con: A.unk nam trong B.unk thi B\A co rem[B]-rem[A] mine.
      for (final a in unk.entries) {
        final ar = a.key ~/ cols;
        final ac = a.key % cols;
        for (var dr = -2; dr <= 2; dr++) {
          for (var dc = -2; dc <= 2; dc++) {
            final br = ar + dr;
            final bc = ac + dc;
            if ((dr == 0 && dc == 0) ||
                br < 0 ||
                br >= rows ||
                bc < 0 ||
                bc >= cols) {
              continue;
            }
            final bk = idx(br, bc);
            final bu = unk[bk];
            if (bu == null || bu.length <= a.value.length) continue;
            if (!a.value.every(bu.contains)) continue;
            final diff = bu.where((n) => !a.value.contains(n)).toList();
            final dm = rem[bk]! - rem[a.key]!;
            if (dm == 0) {
              resolve(diff, isMine: false);
            } else if (dm == diff.length) {
              resolve(diff, isMine: true);
            }
          }
        }
      }
    }
    return left == 0;
  }

  /// Mo o (r,c). Tra ve danh sach o vua duoc mo (theo thu tu lan ra), rong neu
  /// khong mo duoc; thua thi `lost` = true va `boom` la o trung mine.
  List<(int, int)> open(int r, int c, {Random? rng}) {
    if (over) return const [];
    final cell = cells[r][c];
    if (cell.flag || cell.open) return const [];
    if (!placed) _place(r, c, rng ?? Random());
    if (cell.mine) {
      lost = true;
      boom = (r, c);
      return const [];
    }
    final opened = <(int, int)>[];
    final queue = [(r, c)];
    var head = 0;
    while (head < queue.length) {
      final (cr, cc) = queue[head++];
      final cur = cells[cr][cc];
      if (cur.open || cur.flag) continue;
      cur.open = true;
      opened.add((cr, cc));
      if (cur.near == 0) queue.addAll(_neighbors(cr, cc));
    }
    return opened;
  }

  /// Chord: o (r,c) la so da mo va du co quanh no thi mo cac o ke chua co.
  /// Co sai vi tri thi co the nổ mine. Tra ve cac o vua mo.
  List<(int, int)> chord(int r, int c) {
    if (over || !placed) return const [];
    final cell = cells[r][c];
    if (!cell.open || cell.near == 0) return const [];
    final around = _neighbors(r, c).toList();
    final flags = around.where((p) => cells[p.$1][p.$2].flag).length;
    if (flags != cell.near) return const [];
    final opened = <(int, int)>[];
    for (final p in around) {
      final n = cells[p.$1][p.$2];
      if (n.open || n.flag) continue;
      opened.addAll(open(p.$1, p.$2));
      if (lost) break;
    }
    return opened;
  }

  void toggleFlag(int r, int c) {
    if (over) return;
    final cell = cells[r][c];
    if (cell.open) return;
    cell.flag = !cell.flag;
  }

  /// Khi thang: cam co tren moi mine.
  List<(int, int)> flagAllMines() {
    final out = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = cells[r][c];
        if (cell.mine && !cell.flag) {
          cell.flag = true;
          out.add((r, c));
        }
      }
    }
    return out;
  }

  /// Goi y: mot o CHAC CHAN an toan suy ra chi tu cac so da mo (khong dung
  /// vi tri mine that, khong tin co cua nguoi choi) bang hai luat don gian:
  /// (1) so == so o chua mo ke ben => tat ca la mine;
  /// (2) so == so mine da biet => cac o con lai an toan.
  /// Tra ve null neu chua suy ra duoc. Uu tien o chua cam co.
  (int, int)? safeHint() {
    if (!placed || over) return null;
    final mineSet = <int>{};
    final safeSet = <int>{};
    int id((int, int) p) => p.$1 * cols + p.$2;
    var changed = true;
    while (changed) {
      changed = false;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final cell = cells[r][c];
          if (!cell.open || cell.near == 0) continue;
          final closed = _neighbors(
            r,
            c,
          ).where((p) => !cells[p.$1][p.$2].open).toList();
          final known = closed.where((p) => mineSet.contains(id(p))).length;
          final unknown = closed
              .where(
                (p) => !mineSet.contains(id(p)) && !safeSet.contains(id(p)),
              )
              .toList();
          if (unknown.isEmpty) continue;
          final remaining = cell.near - known;
          if (remaining == unknown.length) {
            mineSet.addAll(unknown.map(id));
            changed = true;
          } else if (remaining == 0) {
            safeSet.addAll(unknown.map(id));
            changed = true;
          }
        }
      }
    }
    (int, int)? flaggedSafe;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (cells[r][c].open || !safeSet.contains(r * cols + c)) continue;
        if (!cells[r][c].flag) return (r, c);
        flaggedSafe ??= (r, c);
      }
    }
    return flaggedSafe;
  }
}
