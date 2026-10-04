/// Cac game xoay vong lam thu thach moi ngay (deu sinh de theo seed).
const dailyGameIds = <String>[
  'sudoku',
  'kakuro',
  'lights_out',
  'sliding',
  'minesweeper',
  'memory',
];

/// Khoa ngay dang yyyyMMdd (gio dia phuong).
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String k) => DateTime(
  int.parse(k.substring(0, 4)),
  int.parse(k.substring(4, 6)),
  int.parse(k.substring(6, 8)),
);

/// Ngay lien truoc (an toan voi gio mua he).
DateTime previousDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);

/// Game cua ngay [d]; moi may cung ra cung mot game.
String dailyGameFor(DateTime d) {
  final days = DateTime.utc(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime.utc(2026)).inDays;
  final n = dailyGameIds.length;
  return dailyGameIds[((days % n) + n) % n];
}

/// Seed co dinh theo ngay + game, de moi may sinh cung mot de.
int dailySeed(String key, String gameId) {
  var h = 17;
  for (final c in '$key:$gameId'.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}
