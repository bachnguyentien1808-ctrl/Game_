import 'dart:math';

/// Cong thuc tinh diem khi thang, thuan Dart (khong import Flutter).
///
/// Cang thang nhanh diem cang cao, cang cham diem giam dan nhung khong thap
/// hon [floor] cua diem toi da:
/// - nhanh hon `par * 0.5` giay: du 100% toc do;
/// - cham hon `par * 3` giay: toc do ve 0;
/// - o giua giam deu.
/// Moi loi tru [mistakePenalty], moi lan goi y tru [hintPenalty] (tinh tren
/// phan tram diem), ket qua lam tron den chuc.
abstract final class Scoring {
  static const floor = 0.25;
  static const mistakePenalty = 0.05;
  static const hintPenalty = 0.08;
  static const maxPenalty = 0.5;

  /// He so toc do 0..1 theo thoi gian [seconds] so voi thoi gian chuan
  /// [parSeconds].
  static double speed(int seconds, int parSeconds) {
    final par = max(1, parSeconds);
    final fast = par * 0.5;
    final slow = par * 3.0;
    return (1 - (seconds - fast) / (slow - fast)).clamp(0.0, 1.0);
  }

  /// Diem cho mot van thang.
  /// [base] diem goc cua game o muc co ban; [mult] he so do kho/kich thuoc.
  static int points({
    required int base,
    required int seconds,
    required int parSeconds,
    double mult = 1,
    int mistakes = 0,
    int hints = 0,
  }) {
    final sp = speed(seconds, parSeconds);
    final timeFactor = floor + (1 - floor) * sp;
    final penalty = min(
      maxPenalty,
      mistakes * mistakePenalty + hints * hintPenalty,
    );
    final raw = base * mult * timeFactor * (1 - penalty);
    return max(10, (raw / 10).round() * 10);
  }

  /// "12345" -> "12.345" (dau cham ngan cach hang nghin kieu Viet).
  static String format(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
