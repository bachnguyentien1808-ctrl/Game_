import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/score/scoring.dart';

void main() {
  int pts(int sec, {int mistakes = 0, int hints = 0, double mult = 1}) =>
      Scoring.points(
        base: 1000,
        seconds: sec,
        parSeconds: 300,
        mult: mult,
        mistakes: mistakes,
        hints: hints,
      );

  test('Nhanh diem cao, cham diem giam dan, khong xuong duoi san', () {
    final fast = pts(100);
    final par = pts(300);
    final slow = pts(600);
    final veryslow = pts(5000);
    expect(fast, 1000);
    expect(fast, greaterThan(par));
    expect(par, greaterThan(slow));
    expect(slow, greaterThan(veryslow));
    expect(veryslow, 250);
  });

  test('Loi va goi y tru diem, he so do kho nhan len', () {
    expect(pts(100, mistakes: 2), lessThan(pts(100)));
    expect(pts(100, hints: 1), lessThan(pts(100)));
    expect(pts(100, mistakes: 100), 500);
    expect(pts(100, mult: 2), 2000);
  });

  test('format dung dau cham hang nghin', () {
    expect(Scoring.format(0), '0');
    expect(Scoring.format(950), '950');
    expect(Scoring.format(12340), '12.340');
    expect(Scoring.format(1234567), '1.234.567');
  });
}
