import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_solver.dart';

/// De mau (giai duoc bang single) va dap an.
const _easy =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const _easySol =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

List<int> _g(String s) => [for (final c in s.codeUnits) c - 48];

void main() {
  group('SudokuEngine', () {
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

    test('countFlat: luoi mau duy nhat, luoi rong nhieu, luoi mau thuan 0', () {
      expect(SudokuEngine.countFlat(_g(_easy)), 1);
      expect(SudokuEngine.countFlat(List.filled(81, 0)), 2);
      final bad = _g(_easy)..[2] = 5; // trung so 5 o hang 0
      expect(SudokuEngine.countFlat(bad), 0);
    });

    test('solve giai dung de mau', () {
      final g = SudokuEngine.unflatten(_g(_easy));
      expect(SudokuEngine.solve(g), isTrue);
      expect(SudokuEngine.flatten(g), _g(_easySol));
    });

    test('generateLevel: cung seed cung de, de duy nhat, dap an hop le', () {
      for (final lv in SudokuLevel.values) {
        final a = SudokuEngine.generateLevel(lv, seed: 42);
        final b = SudokuEngine.generateLevel(lv, seed: 42);
        expect(a.puzzle, b.puzzle, reason: lv.name);
        expect(SudokuEngine.countFlat(a.puzzle), 1, reason: lv.name);
        for (var i = 0; i < 81; i++) {
          if (a.puzzle[i] != 0) expect(a.puzzle[i], a.solution[i]);
        }
        expect(SudokuEngine.countFlat(a.solution), 1);
        expect(a.solution.contains(0), isFalse);
      }
    });

    test('de nhieu muc kho thi nhieu o trong hon', () {
      int holes(SudokuLevel l) => SudokuEngine.generateLevel(
        l,
        seed: 7,
      ).puzzle.where((v) => v == 0).length;
      expect(holes(SudokuLevel.easy), lessThan(holes(SudokuLevel.hard)));
      expect(holes(SudokuLevel.medium), lessThan(holes(SudokuLevel.expert)));
    });

    test('de De/Vua/Kho giai duoc bang ky thuat', () {
      for (final lv in [
        SudokuLevel.easy,
        SudokuLevel.medium,
        SudokuLevel.hard,
      ]) {
        for (var seed = 0; seed < 5; seed++) {
          final p = SudokuEngine.generateLevel(lv, seed: seed).puzzle;
          expect(
            SudokuSolver.solveLogically(p).solved,
            isTrue,
            reason: '${lv.name} seed $seed',
          );
        }
      }
    });

    test('thoi gian sinh de < 300ms moi muc (trung binh, xau nhat)', () {
      // Lam nong JIT.
      SudokuEngine.generateLevel(SudokuLevel.medium, seed: 1);
      final out = <String>[];
      for (final lv in SudokuLevel.values) {
        var worst = 0;
        var sum = 0;
        for (var seed = 100; seed < 110; seed++) {
          final sw = Stopwatch()..start();
          SudokuEngine.generateLevel(lv, seed: seed);
          final ms = sw.elapsedMilliseconds;
          sum += ms;
          worst = max(worst, ms);
        }
        out.add('${lv.name}: tb ${sum ~/ 10}ms, max ${worst}ms');
        expect(worst, lessThan(300), reason: lv.name);
      }
      // In so do de theo doi hieu nang sinh de.
      // ignore: avoid_print
      print('Do sinh de: ${out.join('; ')}');
    });
  });

  group('SudokuSolver', () {
    test('peers 20 o, units 27 don vi 9 o', () {
      expect(SudokuSolver.units.length, 27);
      expect(SudokuSolver.units.every((u) => u.toSet().length == 9), isTrue);
      expect(SudokuSolver.peers.every((p) => p.length == 20), isTrue);
      expect(SudokuSolver.boxOf(0), 0);
      expect(SudokuSolver.boxOf(80), 8);
      expect(SudokuSolver.boxOf(4 * 9 + 4), 4);
    });

    test('naked single: o chi con mot ung vien', () {
      // Hang 0 co 1..8, o cuoi chi con 9.
      final g = List<int>.filled(81, 0);
      for (var c = 0; c < 8; c++) {
        g[c] = c + 1;
      }
      final s = SudokuSolver.nakedAt(g, 8)!;
      expect(s.value, 9);
      expect(s.technique, SudokuTechnique.nakedSingle);
      expect(s.explanation, contains('chỉ còn điền được số 9'));
      expect(SudokuSolver.nakedAt(g, 9), isNull);
    });

    test('hidden single: so chi dat duoc mot cho trong hang', () {
      // So 1 o cot 1..8 (hang khac nhau, ngoai khoi chua o 0) chan hang 0
      // tru o (0,0).
      final g = List<int>.filled(81, 0);
      g[3 * 9 + 1] = 1;
      g[6 * 9 + 2] = 1;
      g[1 * 9 + 3] = 1; // khoi 1
      g[4 * 9 + 4] = 1;
      g[7 * 9 + 5] = 1;
      g[2 * 9 + 6] = 1; // khoi 2
      g[5 * 9 + 7] = 1;
      g[8 * 9 + 8] = 1;
      final s = SudokuSolver.hiddenAt(g, 0)!;
      expect(s.value, 1);
      expect(s.technique, SudokuTechnique.hiddenSingle);
      expect(s.unit, SudokuSolver.units[0]);
      expect(s.explanation, contains('Trong hàng 1, số 1'));
    });

    test('solveLogically giai de mau dung dap an', () {
      final r = SudokuSolver.solveLogically(_g(_easy));
      expect(r.solved, isTrue);
      expect(r.grid, _g(_easySol));
      expect(r.naked + r.hidden, _g(_easy).where((v) => v == 0).length);
    });

    test('nextStep luon dung voi dap an', () {
      final g = _g(_easy);
      final sol = _g(_easySol);
      while (true) {
        final s = SudokuSolver.nextStep(g);
        if (s == null) break;
        expect(s.value, sol[s.index]);
        g[s.index] = s.value;
      }
      expect(g, sol);
    });

    test('rate: it o trong la De, de khong giai duoc bang single la Chuyen gia', () {
      // De mau 51 o trong -> Kho; bo 21 o tu dap an -> De.
      expect(SudokuSolver.rate(_g(_easy)), SudokuLevel.hard);
      final few = _g(_easySol);
      for (var i = 0; i < 81; i += 4) {
        few[i] = 0;
      }
      expect(SudokuSolver.rate(few), SudokuLevel.easy);
      // De "AI Escargot" can ky thuat cao.
      const hard =
          '100007090030020008009600500005300900010080002600004000300000010040000007007000300';
      expect(SudokuSolver.rate(_g(hard)), SudokuLevel.expert);
    });
  });
}
