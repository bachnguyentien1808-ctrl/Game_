/// Cac man nonogram: '#' = o to, '.' = o trong.
const nonogramPuzzles = <({String name, List<String> rows})>[
  (name: 'Trái tim 5x5', rows: ['.#.#.', '#####', '#####', '.###.', '..#..']),
  (
    name: 'Ngôi nhà 7x7',
    rows: [
      '...#...',
      '..###..',
      '.#####.',
      '#######',
      '.##.##.',
      '.##.##.',
      '.#####.',
    ],
  ),
  (
    name: 'Cây thông 8x8',
    rows: [
      '...##...',
      '..####..',
      '...##...',
      '..####..',
      '.######.',
      '...##...',
      '...##...',
      '..####..',
    ],
  ),
];

/// Day so goi y cua mot hang/cot (vd '#.##' -> [1, 2]).
List<int> clueOf(List<bool> line) {
  final out = <int>[];
  var run = 0;
  for (final f in line) {
    if (f) {
      run++;
    } else if (run > 0) {
      out.add(run);
      run = 0;
    }
  }
  if (run > 0) out.add(run);
  return out.isEmpty ? [0] : out;
}

class NonogramPuzzle {
  NonogramPuzzle(List<String> rows)
    : solution = [
        for (final r in rows) [for (final ch in r.split('')) ch == '#'],
      ];

  final List<List<bool>> solution;

  int get size => solution.length;

  List<List<int>> get rowClues => [for (final r in solution) clueOf(r)];

  List<List<int>> get colClues => [
    for (var c = 0; c < size; c++)
      clueOf([for (var r = 0; r < size; r++) solution[r][c]]),
  ];

  /// grid: 0 trong, 1 to, 2 danh dau X. Dung khi moi o 'to' khop dap an.
  bool isSolved(List<List<int>> grid) {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if ((grid[r][c] == 1) != solution[r][c]) return false;
      }
    }
    return true;
  }
}
