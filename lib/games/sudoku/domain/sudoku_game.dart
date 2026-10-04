import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_solver.dart';

/// Thay doi cua mot o trong mot nuoc di (de hoan tac/lam lai).
class CellChange {
  const CellChange(this.index, this.fromV, this.fromN, this.toV, this.toN);

  final int index;
  final int fromV;
  final int fromN;
  final int toV;
  final int toN;
}

/// Ket qua dat so.
class PlaceResult {
  const PlaceResult({
    this.changed = false,
    this.wrong = false,
    this.completed = const [],
  });

  final bool changed;
  final bool wrong;

  /// Cac don vi (hang/cot/khoi) vua hoan thanh dung, moi don vi 9 o.
  final List<List<int>> completed;
}

/// Ket qua goi y.
class HintResult {
  const HintResult({
    required this.index,
    required this.value,
    required this.explanation,
    required this.unit,
    required this.place,
  });

  final int index;
  final int value;
  final String explanation;
  final List<int> unit;
  final PlaceResult place;
}

/// Trang thai mot van Sudoku: luoi, ghi chu (bitmask bit 1..9), loi, goi y,
/// thoi gian, hoan tac/lam lai. Thuan Dart de test.
class SudokuGame {
  SudokuGame({
    required this.puzzle,
    required this.solution,
    required this.level,
    List<int>? values,
    List<int>? notes,
    Set<int>? hinted,
    this.mistakes = 0,
    this.hintsUsed = 0,
    this.elapsed = 0,
    this.mistakeLimit = true,
  }) : values = values ?? List<int>.of(puzzle),
       notes = notes ?? List<int>.filled(81, 0),
       hinted = hinted ?? <int>{};

  factory SudokuGame.fromJson(Map<String, dynamic> j) {
    List<int> digits(Object? o) {
      final s = o! as String;
      if (s.length != 81) throw const FormatException('luoi sai do dai');
      return [for (final ch in s.codeUnits) ch - 48];
    }

    final g = SudokuGame(
      puzzle: digits(j['p']),
      solution: digits(j['s']),
      values: digits(j['v']),
      notes: (j['n']! as List).cast<int>().toList(),
      hinted: ((j['hi'] as List?) ?? const []).cast<int>().toSet(),
      level: SudokuLevel.byName(j['lv'] as String?),
      mistakes: j['m'] as int? ?? 0,
      hintsUsed: j['h'] as int? ?? 0,
      elapsed: j['t'] as int? ?? 0,
      mistakeLimit: j['ml'] as bool? ?? true,
    );
    if (g.notes.length != 81) throw const FormatException('ghi chu sai');
    return g;
  }

  /// Bat dau van moi tu de cua engine.
  factory SudokuGame.fresh(
    ({List<int> puzzle, List<int> solution}) gen,
    SudokuLevel level, {
    bool mistakeLimit = true,
  }) => SudokuGame(
    puzzle: gen.puzzle,
    solution: gen.solution,
    level: level,
    mistakeLimit: mistakeLimit,
  );

  static const maxMistakes = 3;
  static const maxHints = 3;

  final List<int> puzzle;
  final List<int> solution;
  final SudokuLevel level;
  final List<int> values;
  final List<int> notes;

  /// O da dien bang goi y (khoa, khong hoan tac).
  final Set<int> hinted;
  int mistakes;
  int hintsUsed;

  /// Giay da choi.
  int elapsed;
  bool mistakeLimit;

  final List<List<CellChange>> _undo = [];
  final List<List<CellChange>> _redo = [];

  bool get canUndo => _undo.isNotEmpty && !isOver;
  bool get canRedo => _redo.isNotEmpty && !isOver;

  bool isGiven(int i) => puzzle[i] != 0;
  bool isLocked(int i) => isGiven(i) || hinted.contains(i);
  bool isWrong(int i) => values[i] != 0 && values[i] != solution[i];

  bool get isWon {
    for (var i = 0; i < 81; i++) {
      if (values[i] != solution[i]) return false;
    }
    return true;
  }

  bool get isLost => mistakeLimit && mistakes >= maxMistakes;
  bool get isOver => isWon || isLost;
  int get hintsLeft => maxHints - hintsUsed;

  /// So o da dien dung chu so [d] (de mo nut khi du 9).
  int countOf(int d) {
    var n = 0;
    for (var i = 0; i < 81; i++) {
      if (values[i] == d && solution[i] == d) n++;
    }
    return n;
  }

  bool hasNote(int i, int d) => notes[i] & (1 << d) != 0;

  void _apply(List<CellChange> m, {bool toNew = true}) {
    for (final ch in m) {
      values[ch.index] = toNew ? ch.toV : ch.fromV;
      notes[ch.index] = toNew ? ch.toN : ch.fromN;
    }
  }

  void _push(List<CellChange> m) {
    if (m.isEmpty) return;
    _undo.add(m);
    if (_undo.length > 200) _undo.removeAt(0);
    _redo.clear();
  }

  /// Dat chu so [v] (1..9) vao o [i]. Tu xoa ghi chu cua o va ghi chu [v]
  /// cua cac o lien quan. Sai thi tang [mistakes].
  PlaceResult place(int i, int v, {bool record = true}) {
    if (isLocked(i) || isOver || values[i] == v) return const PlaceResult();
    final m = <CellChange>[CellChange(i, values[i], notes[i], v, 0)];
    final bit = 1 << v;
    for (final j in SudokuSolver.peers[i]) {
      if (notes[j] & bit != 0) {
        m.add(CellChange(j, values[j], notes[j], values[j], notes[j] & ~bit));
      }
    }
    _apply(m);
    if (record) _push(m);
    final wrong = v != solution[i];
    if (wrong) mistakes++;
    return PlaceResult(
      changed: true,
      wrong: wrong,
      completed: wrong ? const [] : completedUnitsAt(i),
    );
  }

  /// Bat/tat ghi chu [v] o o [i] (chi o trong).
  bool toggleNote(int i, int v) {
    if (isLocked(i) || isOver || values[i] != 0) return false;
    final n = notes[i] ^ (1 << v);
    final m = [CellChange(i, 0, notes[i], 0, n)];
    _apply(m);
    _push(m);
    return true;
  }

  /// Xoa so/ghi chu o o [i].
  bool erase(int i) {
    if (isLocked(i) || isOver || (values[i] == 0 && notes[i] == 0)) {
      return false;
    }
    final m = [CellChange(i, values[i], notes[i], 0, 0)];
    _apply(m);
    _push(m);
    return true;
  }

  /// Hoan tac; tra ve o chinh cua nuoc vua hoan tac (hoac null).
  int? undo() {
    if (!canUndo) return null;
    final m = _undo.removeLast();
    _apply([
      for (final ch in m)
        if (!isLocked(ch.index)) ch,
    ], toNew: false);
    _redo.add(m);
    return m.first.index;
  }

  int? redo() {
    if (!canRedo) return null;
    final m = _redo.removeLast();
    _apply([
      for (final ch in m)
        if (!isLocked(ch.index)) ch,
    ]);
    _undo.add(m);
    return m.first.index;
  }

  /// Don vi vua hoan thanh dung chua o [i].
  List<List<int>> completedUnitsAt(int i) => [
    for (final u in [i ~/ 9, 9 + i % 9, 18 + SudokuSolver.boxOf(i)])
      if (SudokuSolver.units[u].every((j) => values[j] == solution[j]))
        SudokuSolver.units[u],
  ];

  /// Luoi chi gom cac so dung (bo so sai) de suy luan.
  List<int> _cleanGrid() => [
    for (var i = 0; i < 81; i++) isWrong(i) ? 0 : values[i],
  ];

  /// Tim goi y (khong ap dung). Uu tien: sua o sai, suy luan tai o dang chon,
  /// suy luan bat ky, cuoi cung la lo dap an o dang chon/o trong dau tien.
  HintResult? findHint(int? selected) {
    if (isOver) return null;
    // 1. O sai.
    int? wrongAt;
    if (selected != null && isWrong(selected)) {
      wrongAt = selected;
    } else {
      for (var i = 0; i < 81; i++) {
        if (isWrong(i)) {
          wrongAt = i;
          break;
        }
      }
    }
    if (wrongAt != null) {
      return HintResult(
        index: wrongAt,
        value: solution[wrongAt],
        explanation:
            'Số ${values[wrongAt]} ở ô hàng ${wrongAt ~/ 9 + 1}, cột '
            '${wrongAt % 9 + 1} không đúng; đáp án là ${solution[wrongAt]}.',
        unit: const [],
        place: const PlaceResult(),
      );
    }
    final g = _cleanGrid();
    // 2. Suy luan tai o dang chon.
    if (selected != null && g[selected] == 0) {
      final s = SudokuSolver.stepAt(g, selected);
      if (s != null) return _fromStep(s);
    }
    // 3. Suy luan bat ky.
    final s = SudokuSolver.nextStep(g);
    if (s != null) return _fromStep(s);
    // 4. Lo dap an.
    final i = (selected != null && g[selected] == 0) ? selected : g.indexOf(0);
    if (i < 0) return null;
    return HintResult(
      index: i,
      value: solution[i],
      explanation:
          'Chưa có suy luận đơn giản cho ô này; đáp án là ${solution[i]}.',
      unit: const [],
      place: const PlaceResult(),
    );
  }

  HintResult _fromStep(SudokuStep s) => HintResult(
    index: s.index,
    value: s.value,
    explanation: s.explanation,
    unit: s.unit,
    place: const PlaceResult(),
  );

  /// Dung mot goi y: dien dap an, khoa o, tru luot goi y.
  HintResult? useHint(int? selected) {
    if (hintsLeft <= 0) return null;
    final h = findHint(selected);
    if (h == null) return null;
    // Xoa so sai truoc (khong tinh loi), roi dat dap an.
    values[h.index] = 0;
    final p = place(h.index, h.value, record: false);
    hinted.add(h.index);
    hintsUsed++;
    return HintResult(
      index: h.index,
      value: h.value,
      explanation: h.explanation,
      unit: h.unit,
      place: p,
    );
  }

  /// Choi lai cung de tu dau.
  void restart() {
    for (var i = 0; i < 81; i++) {
      values[i] = puzzle[i];
      notes[i] = 0;
    }
    hinted.clear();
    mistakes = 0;
    hintsUsed = 0;
    elapsed = 0;
    _undo.clear();
    _redo.clear();
  }

  Map<String, dynamic> toJson() => {
    'p': puzzle.join(),
    's': solution.join(),
    'v': values.join(),
    'n': notes,
    'hi': hinted.toList(),
    'lv': level.name,
    'm': mistakes,
    'h': hintsUsed,
    't': elapsed,
    'ml': mistakeLimit,
  };
}
