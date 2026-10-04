import 'dart:math';

enum Dir { left, right, up, down }

/// Mot chuyen dong cua o trong mot nuoc di: tu (fromR, fromC) den (toR, toC).
/// [merged] = true khi o nay gop vao o khac tai dich; [value] la gia tri truoc khi gop.
class TileMove {
  const TileMove({
    required this.fromR,
    required this.fromC,
    required this.toR,
    required this.toC,
    required this.value,
    required this.merged,
  });

  final int fromR;
  final int fromC;
  final int toR;
  final int toC;
  final int value;
  final bool merged;

  bool get stays => fromR == toR && fromC == toC;
}

/// O moi sinh sau nuoc di.
class Spawn {
  const Spawn(this.r, this.c, this.value);
  final int r;
  final int c;
  final int value;
}

/// Ket qua mot lan truot: danh sach chuyen dong, diem cong them.
class SlideResult {
  const SlideResult(this.moves, this.gain, {required this.changed});
  final List<TileMove> moves;
  final int gain;
  final bool changed;

  /// Cac o dich co gop (toa do) va gia tri sau gop.
  List<(int, int, int)> get merges {
    final out = <(int, int, int)>[];
    final seen = <int>{};
    for (final m in moves) {
      if (!m.merged) continue;
      final key = m.toR * 100 + m.toC;
      if (seen.add(key)) out.add((m.toR, m.toC, m.value * 2));
    }
    return out;
  }
}

class Board2048 {
  Board2048(this.cells, {this.score = 0});

  factory Board2048.start({Random? rng, int size = 4}) {
    final r = rng ?? Random();
    final b = Board2048(List.generate(size, (_) => List.filled(size, 0)));
    b
      ..spawn(r)
      ..spawn(r);
    return b;
  }

  factory Board2048.fromJson(Map<String, dynamic> j) => Board2048([
    for (final r in j['cells'] as List) (r as List).cast<int>().toList(),
  ], score: j['score'] as int);

  final List<List<int>> cells;
  int score;

  int get size => cells.length;

  Map<String, dynamic> toJson() => {'cells': cells, 'score': score};

  Board2048 copy() =>
      Board2048([for (final r in cells) List.of(r)], score: score);

  /// Sinh mot o moi o cho trong; tra ve null neu het cho.
  Spawn? spawn(Random rng) {
    final n = size;
    final empty = <(int, int)>[
      for (var r = 0; r < n; r++)
        for (var c = 0; c < n; c++)
          if (cells[r][c] == 0) (r, c),
    ];
    if (empty.isEmpty) return null;
    final (r, c) = empty[rng.nextInt(empty.length)];
    final v = rng.nextDouble() < 0.9 ? 2 : 4;
    cells[r][c] = v;
    return Spawn(r, c, v);
  }

  (int, int) _coord(Dir d, int i, int j) {
    final n = size;
    return switch (d) {
      Dir.left => (i, j),
      Dir.right => (i, n - 1 - j),
      Dir.up => (j, i),
      Dir.down => (n - 1 - j, i),
    };
  }

  /// Truot theo huong [d] (khong sinh o moi), tra ve chuyen dong cua tung o.
  /// Moi o chi gop toi da mot lan trong mot nuoc.
  SlideResult slide(Dir d) {
    final n = size;
    final moves = <TileMove>[];
    var gain = 0;
    var changed = false;
    for (var i = 0; i < n; i++) {
      final out = List.filled(n, 0);
      final mergedAt = List.filled(n, false);
      var p = 0;
      for (var j = 0; j < n; j++) {
        final (r, c) = _coord(d, i, j);
        final v = cells[r][c];
        if (v == 0) continue;
        if (p > 0 && out[p - 1] == v && !mergedAt[p - 1]) {
          final (tr, tc) = _coord(d, i, p - 1);
          out[p - 1] = v * 2;
          mergedAt[p - 1] = true;
          gain += v * 2;
          moves.add(
            TileMove(
              fromR: r,
              fromC: c,
              toR: tr,
              toC: tc,
              value: v,
              merged: true,
            ),
          );
          changed = true;
        } else {
          final (tr, tc) = _coord(d, i, p);
          out[p] = v;
          if (tr != r || tc != c) changed = true;
          moves.add(
            TileMove(
              fromR: r,
              fromC: c,
              toR: tr,
              toC: tc,
              value: v,
              merged: false,
            ),
          );
          p++;
        }
      }
      for (var j = 0; j < n; j++) {
        final (r, c) = _coord(d, i, j);
        cells[r][c] = out[j];
      }
    }
    score += gain;
    return SlideResult(moves, gain, changed: changed);
  }

  /// Truot (khong sinh o moi); tra ve true neu ban co thay doi.
  bool move(Dir d) => slide(d).changed;

  bool get canMove {
    final n = size;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (cells[r][c] == 0) return true;
        if (c < n - 1 && cells[r][c] == cells[r][c + 1]) return true;
        if (r < n - 1 && cells[r][c] == cells[r + 1][c]) return true;
      }
    }
    return false;
  }

  int get maxTile {
    var m = 0;
    for (final r in cells) {
      for (final v in r) {
        if (v > m) m = v;
      }
    }
    return m;
  }

  bool get reached2048 => maxTile >= 2048;
}

/// Ket qua mot nuoc di cua [Game2048].
class MoveOutcome {
  const MoveOutcome(this.slide, this.spawn, {required this.justWon});
  final SlideResult slide;
  final Spawn? spawn;

  /// Vua dat o muc tieu lan dau (chua bam Tiep tuc).
  final bool justWon;
}

/// Mot van 2048: ban co + hoan tac gioi han + trang thai thang/tiep tuc.
class Game2048 {
  Game2048(
    this.board, {
    List<Board2048>? undoStack,
    this.undosLeft = maxUndos,
    this.won = false,
    this.continued = false,
  }) : undoStack = undoStack ?? [];

  factory Game2048.start({int size = 4, Random? rng}) =>
      Game2048(Board2048.start(rng: rng, size: size));

  factory Game2048.fromJson(Map<String, dynamic> j) {
    final b = Board2048.fromJson(j);
    if (b.size < 3 || b.size > 5 || b.cells.any((r) => r.length != b.size)) {
      throw const FormatException('size');
    }
    return Game2048(
      b,
      undoStack: [
        for (final u in (j['undo'] as List? ?? const []))
          Board2048.fromJson((u as Map).cast<String, dynamic>()),
      ].take(maxUndos).toList(),
      undosLeft: (j['undosLeft'] as int? ?? maxUndos).clamp(0, maxUndos),
      won: j['won'] as bool? ?? false,
      continued: j['continued'] as bool? ?? false,
    );
  }

  static const maxUndos = 3;

  /// O muc tieu theo kich thuoc (3x3 khong the toi 2048).
  static int targetFor(int size) => size == 3 ? 512 : 2048;

  Board2048 board;
  final List<Board2048> undoStack;
  int undosLeft;
  bool won;
  bool continued;

  int get size => board.size;
  int get target => targetFor(size);
  int get score => board.score;
  bool get isOver => !board.canMove;
  bool get canUndo => undosLeft > 0 && undoStack.isNotEmpty;

  /// Di chuyen; null neu khong co gi thay doi.
  MoveOutcome? move(Dir d, Random rng) {
    final before = board.copy();
    final res = board.slide(d);
    if (!res.changed) {
      board = before;
      return null;
    }
    undoStack.add(before);
    while (undoStack.length > maxUndos) {
      undoStack.removeAt(0);
    }
    final sp = board.spawn(rng);
    var justWon = false;
    if (!won && !continued && board.maxTile >= target) {
      won = true;
      justWon = true;
    }
    return MoveOutcome(res, sp, justWon: justWon);
  }

  /// Hoan tac mot nuoc; false neu het luot hoac khong co gi de hoan tac.
  bool undo() {
    if (!canUndo) return false;
    board = undoStack.removeLast();
    undosLeft--;
    return true;
  }

  Map<String, dynamic> toJson() => {
    ...board.toJson(),
    'undo': [for (final u in undoStack) u.toJson()],
    'undosLeft': undosLeft,
    'won': won,
    'continued': continued,
  };
}
