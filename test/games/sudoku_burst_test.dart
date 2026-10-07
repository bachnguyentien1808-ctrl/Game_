import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/sudoku/presentation/sudoku_burst.dart';

const _sol =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

List<int> _g(String s) => [for (final c in s.codeUnits) c - 48];

void main() {
  test('detectCompletion: hang day dung va khong nhay khi con thieu', () {
    final v = _g(_sol);
    expect(detectCompletion(v, 0).rows, [0]);
    final miss = List<int>.of(v)..[4] = 0;
    expect(detectCompletion(miss, 0).rows, isEmpty);
    expect(detectCompletion(miss, 0).cols, [0]);
  });

  test('detectCompletion: khoi, so du 9 va thong bao', () {
    final v = _g(_sol);
    final d = detectCompletion(v, 0);
    expect(d.boxes, [0]);
    expect(d.digit, 5);
    expect(d.messages, ['Hàng 1, Cột 1 và Khối 1 xong!', 'Đã đủ số 5!']);
    final part = List<int>.of(v)..[40] = 0; // o 5 giua bang
    expect(detectCompletion(part, 0).digit, isNull);
    expect(detectCompletion(List<int>.filled(81, 0), 0).isEmpty, isTrue);
  });

  test(
    'Diem thuong: khoi nhieu hon hang/cot, moi don vi chi thuong mot lan',
    () {
      final seen = <String>{};
      const row = SudokuCompletion(rows: [2]);
      const col = SudokuCompletion(cols: [4]);
      const box = SudokuCompletion(boxes: [1]);
      expect(row.takeNew(seen).points(1), 30);
      expect(col.takeNew(seen).points(1), 30);
      expect(box.takeNew(seen).points(1), 60);
      expect(box.takeNew(seen).isEmpty, isTrue, reason: 'da thuong roi');
      expect(const SudokuCompletion(rows: [3]).points(2), 60);
      const all = SudokuCompletion(rows: [0], cols: [0], boxes: [0], digit: 5);
      // 3 don vi cung luc: (30 + 30 + 60 + 40) x combo 2.
      expect(all.takeNew(<String>{}).points(1), 320);
      // Hang + khoi cung luc: (30 + 60) x 1.5.
      expect(const SudokuCompletion(rows: [0], boxes: [0]).points(1), 140);
      expect(const SudokuCompletion(rows: [0], boxes: [0]).combo, 1.5);
      expect(const SudokuCompletion().points(3), 0);
    },
  );

  test('Khoa o: hang/cot/khoi da xong dung thi khong sua duoc', () {
    final v = _g(_sol);
    final part = List<int>.of(v)..[0] = 0; // o dau trong
    final locked = lockedCells(part, (_) => false);
    expect(locked.contains(0), isFalse);
    // O 1 nam trong hang 1 chua day nhung cot 2 da day dung => van bi khoa.
    expect(locked.contains(1), isTrue, reason: 'cot 2 day dung');
    expect(locked.contains(80), isTrue, reason: 'hang 9, cot 9, khoi 9 day');
    expect(lockedCells(v, (_) => false).length, 81);
    // Hang co o sai thi khong khoa hang do, nhung o van nam trong don vi khac
    // da day dung: o 40 chi bi chan khi moi don vi chua no deu co o sai.
    expect(lockedCells(v, (_) => true), isEmpty);
  });

  test('fullUnitKeys liet ke cac don vi day', () {
    final v = _g(_sol);
    expect(fullUnitKeys(v).length, 27);
    final part = List<int>.of(v)..[0] = 0;
    final keys = fullUnitKeys(part);
    expect(keys.contains('r0'), isFalse);
    expect(keys.contains('c0'), isFalse);
    expect(keys.contains('b0'), isFalse);
    expect(keys.contains('r8'), isTrue);
  });
}
