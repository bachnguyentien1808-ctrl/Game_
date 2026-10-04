import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/kakuro/domain/kakuro_engine.dart';

void main() {
  test('cung seed sinh cung de', () {
    final a = KakuroPuzzle.generate(rng: Random(42));
    final b = KakuroPuzzle.generate(rng: Random(42));
    expect(a.solution, b.solution);
    expect(a.across, b.across);
    expect(a.down, b.down);
  });

  test('moi kich thuoc: hang/cot 0 den, moi doan dai >=2, loi giai hop le', () {
    for (final n in [5, 6, 7]) {
      for (var seed = 0; seed < 15; seed++) {
        final p = KakuroPuzzle.generate(n: n, rng: Random(seed));
        expect(p.size, n + 1);
        for (var i = 0; i < p.size; i++) {
          expect(p.isWhite(0, i), isFalse);
          expect(p.isWhite(i, 0), isFalse);
        }
        expect(p.whiteCount, greaterThanOrEqualTo((n * n * 0.45).ceil()));
        for (final run in p.runs) {
          expect(run.length, greaterThanOrEqualTo(2));
          expect(p.runSolved(p.solution, run), isTrue);
        }
        // moi o trang thuoc dung mot doan ngang va mot doan doc
        for (var r = 0; r < p.size; r++) {
          for (var c = 0; c < p.size; c++) {
            if (!p.isWhite(r, c)) continue;
            expect(p.acrossRunOf[r][c], isNot(-1));
            expect(p.downRunOf[r][c], isNot(-1));
          }
        }
        expect(p.isSolved(p.solution), isTrue);
        expect(p.errors(p.solution), isEmpty);
      }
    }
  });

  // Luoi 3x3 (n = 2): o trang (1,1)(1,2)(2,1)(2,2).
  final small = KakuroPuzzle.fromSolution([
    [0, 0, 0],
    [0, 1, 2],
    [0, 3, 4],
  ]);

  test('goi y tinh tu loi giai', () {
    expect(small.across[1][0], 3);
    expect(small.across[2][0], 7);
    expect(small.down[0][1], 4);
    expect(small.down[0][2], 6);
    expect(small.runs.length, 4);
  });

  test('solved chap nhan dap an khac loi giai sinh ra', () {
    // ngang 4 va 6, doc 5 va 5: dap an khac 3,1 / 2,4
    final p = KakuroPuzzle.fromSolution([
      [0, 0, 0],
      [0, 1, 3],
      [0, 4, 2],
    ]);
    final alt = [
      [0, 0, 0],
      [0, 3, 1],
      [0, 2, 4],
    ];
    expect(p.isSolved(alt), isTrue);
    expect(alt, isNot(p.solution));
    final grid = small.emptyGrid();
    expect(small.isSolved(grid), isFalse);
  });

  test('errors: trung, vuot tong, du o sai tong', () {
    final g = small.emptyGrid()
      ..[1][1] = 2
      ..[1][2] = 2;
    expect(small.errors(g), containsAll([(1, 1), (1, 2)]));

    final over = small.emptyGrid()..[1][1] = 5; // ngang 3, doc 4 deu vuot
    expect(small.errors(over), {(1, 1)});

    final full = small.emptyGrid()
      ..[2][1] = 1
      ..[2][2] = 5; // tong 6 != 7
    expect(small.errors(full), containsAll([(2, 1), (2, 2)]));

    final ok = small.emptyGrid()..[1][1] = 1;
    expect(small.errors(ok), isEmpty);
  });

  test('toJson/fromJson khop', () {
    final p = KakuroPuzzle.generate(n: 5, rng: Random(3));
    final back = KakuroPuzzle.fromJson(p.toJson());
    expect(back.solution, p.solution);
    expect(back.runs.length, p.runs.length);
  });

  test('fromJson hong nem loi', () {
    expect(
      () => KakuroPuzzle.fromJson({
        's': [
          [1, 0],
          [0, 0],
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
