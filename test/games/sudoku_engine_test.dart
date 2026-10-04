import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';

void main() {
  test('generate cho de co loi giai duy nhat va khop dap an', () {
    final g = SudokuEngine.generate(holes: 40, rng: Random(1));
    expect(SudokuEngine.countSolutions(SudokuEngine.copy(g.puzzle)), 1);
    final solved = SudokuEngine.copy(g.puzzle);
    expect(SudokuEngine.solve(solved), isTrue);
    expect(solved, g.solution);
  });

  test('canPlace chan so trung hang', () {
    final g = SudokuEngine.empty()..[0][0] = 5;
    expect(SudokuEngine.canPlace(g, 0, 8, 5), isFalse);
    expect(SudokuEngine.canPlace(g, 1, 8, 5), isTrue);
  });
}
