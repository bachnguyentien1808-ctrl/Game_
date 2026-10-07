/// Buoi trong ngay dung de chon nen: sang (ngay), chieu (hoang hon), toi (dem).
enum DayPhase {
  day(''),
  dusk('_dusk'),
  night('_night');

  DayPhase(this.suffix);

  /// Hau to ten file anh nen: bg_1.webp / bg_1_dusk.webp / bg_1_night.webp.
  final String suffix;

  /// Chi dung giao dien toi (chu sang) khi chieu va toi.
  bool get isDark => this != day;

  /// Buoi theo gio dia phuong: 05:30-16:29 ngay, 16:30-18:59 chieu, con lai toi.
  static DayPhase at(DateTime t) {
    final m = t.hour * 60 + t.minute;
    if (m >= 5 * 60 + 30 && m < 16 * 60 + 30) return day;
    if (m >= 16 * 60 + 30 && m < 19 * 60) return dusk;
    return night;
  }
}
