import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';

/// Ky thuat suy luan cua bo giai.
enum SudokuTechnique { nakedSingle, hiddenSingle }

/// Mot buoc suy luan: dat [value] vao o [index] (0..80).
class SudokuStep {
  const SudokuStep({
    required this.index,
    required this.value,
    required this.technique,
    required this.unit,
    required this.explanation,
  });

  final int index;
  final int value;
  final SudokuTechnique technique;

  /// Cac o cua don vi (hang/cot/khoi) dung de suy luan; voi naked single la
  /// tat ca o lien quan (hang + cot + khoi).
  final List<int> unit;

  /// Giai thich tieng Viet cho nguoi choi.
  final String explanation;

  int get row => index ~/ 9;
  int get col => index % 9;
}

/// Ket qua giai bang ky thuat.
class SudokuReport {
  const SudokuReport({
    required this.solved,
    required this.naked,
    required this.hidden,
    required this.grid,
  });

  /// Giai het chi bang naked/hidden single.
  final bool solved;
  final int naked;
  final int hidden;

  /// Luoi sau khi dung (co the con o trong neu ![solved]).
  final List<int> grid;
}

/// Bo giai theo ky thuat nguoi choi dung: naked single, hidden single.
/// Dung de cham do kho va tao goi y co giai thich.
abstract final class SudokuSolver {
  /// 27 don vi: 0-8 hang, 9-17 cot, 18-26 khoi 3x3. Moi don vi 9 chi so o.
  static final List<List<int>> units = [
    for (var r = 0; r < 9; r++) [for (var c = 0; c < 9; c++) r * 9 + c],
    for (var c = 0; c < 9; c++) [for (var r = 0; r < 9; r++) r * 9 + c],
    for (var b = 0; b < 9; b++)
      [
        for (var k = 0; k < 9; k++)
          (b ~/ 3 * 3 + k ~/ 3) * 9 + b % 3 * 3 + k % 3,
      ],
  ];

  /// Cac o cung hang/cot/khoi voi moi o (khong gom chinh no), 20 o.
  static final List<List<int>> peers = [
    for (var i = 0; i < 81; i++)
      {
        ...units[i ~/ 9],
        ...units[9 + i % 9],
        ...units[18 + boxOf(i)],
      }.where((j) => j != i).toList(),
  ];

  static int boxOf(int i) => i ~/ 27 * 3 + i % 9 ~/ 3;

  /// Bitmask ung vien (bit 1..9) cua o [i] tren luoi phang [g].
  static int candidates(List<int> g, int i) {
    if (g[i] != 0) return 0;
    var used = 0;
    for (final j in peers[i]) {
      used |= 1 << g[j];
    }
    return ~used & 0x3FE;
  }

  static List<int> _digits(int mask) => [
    for (var v = 1; v <= 9; v++)
      if (mask & (1 << v) != 0) v,
  ];

  /// Naked single tai o [i], hoac null.
  static SudokuStep? nakedAt(List<int> g, int i) {
    final m = candidates(g, i);
    final d = _digits(m);
    if (d.length != 1) return null;
    final r = i ~/ 9 + 1;
    final c = i % 9 + 1;
    return SudokuStep(
      index: i,
      value: d.first,
      technique: SudokuTechnique.nakedSingle,
      unit: peers[i],
      explanation:
          'Ô hàng $r, cột $c chỉ còn điền được số ${d.first}: '
          'các số khác đã có trong hàng, cột hoặc khối 3x3 của ô.',
    );
  }

  /// Hidden single tai o [i] (so chi dat duoc o day trong mot don vi).
  static SudokuStep? hiddenAt(List<int> g, int i) {
    if (g[i] != 0) return null;
    final m = candidates(g, i);
    for (final u in [i ~/ 9, 9 + i % 9, 18 + boxOf(i)]) {
      var others = 0;
      for (final j in units[u]) {
        if (j != i) others |= candidates(g, j);
      }
      // So cua o nay ma khong o nao khac trong don vi dat duoc, va chua co
      // trong don vi.
      var present = 0;
      for (final j in units[u]) {
        present |= 1 << g[j];
      }
      final only = m & ~others & ~present & 0x3FE;
      final d = _digits(only);
      if (d.length == 1) {
        return SudokuStep(
          index: i,
          value: d.first,
          technique: SudokuTechnique.hiddenSingle,
          unit: units[u],
          explanation: _hiddenText(u, i, d.first),
        );
      }
    }
    return null;
  }

  static String _hiddenText(int u, int i, int v) {
    final r = i ~/ 9 + 1;
    final c = i % 9 + 1;
    if (u < 9) {
      return 'Trong hàng $r, số $v chỉ còn đặt được ở ô này (cột $c): '
          'các ô trống khác của hàng đều bị chặn.';
    }
    if (u < 18) {
      return 'Trong cột $c, số $v chỉ còn đặt được ở ô này (hàng $r): '
          'các ô trống khác của cột đều bị chặn.';
    }
    return 'Trong khối 3x3 này, số $v chỉ còn đặt được ở ô hàng $r, cột $c: '
        'các ô trống khác của khối đều bị chặn.';
  }

  /// Buoc suy luan tai mot o cu the (uu tien naked).
  static SudokuStep? stepAt(List<int> g, int i) =>
      nakedAt(g, i) ?? hiddenAt(g, i);

  /// Buoc suy luan tiep theo bat ky tren luoi, hoac null neu het ky thuat.
  /// Uu tien hidden single (nguoi choi de nhin hon), sau do naked single.
  static SudokuStep? nextStep(List<int> g) {
    for (var i = 0; i < 81; i++) {
      final s = hiddenAt(g, i);
      if (s != null) return s;
    }
    for (var i = 0; i < 81; i++) {
      if (g[i] != 0) continue;
      final s = nakedAt(g, i);
      if (s != null) return s;
    }
    return null;
  }

  /// Giai bang ky thuat (khong doan). Hidden single truoc, roi naked single.
  static SudokuReport solveLogically(List<int> puzzle) {
    final g = List<int>.of(puzzle);
    var naked = 0;
    var hidden = 0;
    while (true) {
      final s = nextStep(g);
      if (s == null) break;
      g[s.index] = s.value;
      if (s.technique == SudokuTechnique.nakedSingle) {
        naked++;
      } else {
        hidden++;
      }
    }
    return SudokuReport(
      solved: !g.contains(0),
      naked: naked,
      hidden: hidden,
      grid: g,
    );
  }

  /// Cham do kho mot de (luoi phang 81 o).
  /// - Khong giai duoc bang single: Chuyen gia.
  /// - Can nhieu naked single (>= 8) hoac >= 50 o trong: Kho.
  /// - >= 43 o trong: Vua. Con lai: De.
  static SudokuLevel rate(List<int> puzzle) {
    final rep = solveLogically(puzzle);
    if (!rep.solved) return SudokuLevel.expert;
    final holes = puzzle.where((v) => v == 0).length;
    if (holes >= 50 || rep.naked >= 8) return SudokuLevel.hard;
    if (holes >= 43) return SudokuLevel.medium;
    return SudokuLevel.easy;
  }
}
