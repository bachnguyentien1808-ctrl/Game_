import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_hub/core/daily/daily_challenge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thong ke mot game: so van da bat dau, so van thang, ky luc.
class GameStats {
  const GameStats({this.played = 0, this.won = 0, this.best});

  factory GameStats.fromJson(Map<String, dynamic> j) => GameStats(
    played: j['played'] as int? ?? 0,
    won: j['won'] as int? ?? 0,
    best: j['best'] as int?,
  );

  final int played;
  final int won;
  final int? best;

  Map<String, dynamic> toJson() => {'played': played, 'won': won, 'best': best};
}

/// Doc/ghi tien do va thong ke vao SharedPreferences.
/// [version] tang moi khi du lieu doi de man hinh chinh ve lai.
class ProgressStore {
  ProgressStore(this._prefs);

  final SharedPreferences _prefs;
  final ValueNotifier<int> version = ValueNotifier(0);

  static const _statsPrefix = 'stats.';
  static const _statePrefix = 'state.';

  GameStats stats(String id) {
    final raw = _prefs.getString('$_statsPrefix$id');
    if (raw == null) return const GameStats();
    try {
      return GameStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const GameStats();
    }
  }

  Future<void> _putStats(String id, GameStats s) async {
    await _prefs.setString('$_statsPrefix$id', jsonEncode(s.toJson()));
    version.value++;
  }

  Future<void> recordStart(String id) {
    final s = stats(id);
    return _putStats(
      id,
      GameStats(played: s.played + 1, won: s.won, best: s.best),
    );
  }

  /// Ghi mot van thang; [score] cap nhat ky luc (thap hon la tot neu [lowerIsBetter]).
  Future<void> recordWin(String id, {int? score, bool lowerIsBetter = false}) {
    final s = stats(id);
    return _putStats(
      id,
      GameStats(
        played: s.played,
        won: s.won + 1,
        best: _better(s.best, score, lowerIsBetter),
      ),
    );
  }

  /// Chi cap nhat ky luc (vd diem 2048), khong tinh thang.
  Future<void> recordScore(String id, int score, {bool lowerIsBetter = false}) {
    final s = stats(id);
    final b = _better(s.best, score, lowerIsBetter);
    if (b == s.best) return Future.value();
    return _putStats(id, GameStats(played: s.played, won: s.won, best: b));
  }

  static int? _better(int? old, int? now, bool lower) {
    if (now == null) return old;
    if (old == null) return now;
    return lower ? min(old, now) : max(old, now);
  }

  bool hasState(String id) => _prefs.containsKey('$_statePrefix$id');

  Map<String, dynamic>? loadState(String id) {
    final raw = _prefs.getString('$_statePrefix$id');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveState(String id, Map<String, dynamic> state) async {
    await _prefs.setString('$_statePrefix$id', jsonEncode(state));
    version.value++;
  }

  Future<void> clearState(String id) async {
    await _prefs.remove('$_statePrefix$id');
    version.value++;
  }

  // ---- Thu thach moi ngay ----
  static const _dailyKey = 'daily.done';

  /// Cac ngay da hoan thanh: yyyyMMdd -> diem (co the null).
  Map<String, int?> dailyDone() {
    final raw = _prefs.getString(_dailyKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int?),
      );
    } on Object {
      return {};
    }
  }

  bool isDailyDone(String key) => dailyDone().containsKey(key);

  Future<void> completeDaily(String key, {int? score}) async {
    final m = dailyDone();
    m.putIfAbsent(key, () => score);
    await _prefs.setString(_dailyKey, jsonEncode(m));
    await pruneDaily();
  }

  /// Xoa trang thai van thu thach ngay cu (giu lai cua ngay [keep]).
  Future<void> pruneDaily({String? keep}) async {
    final stale = _prefs.getKeys().where(
      (k) =>
          k.startsWith('${_statePrefix}daily.') &&
          (keep == null || !k.endsWith('.$keep')),
    );
    for (final k in stale.toList()) {
      await _prefs.remove(k);
    }
    version.value++;
  }

  /// Chuoi ngay lien tiep dang con; neu hom nay chua xong thi tinh tu hom qua.
  int currentStreak(DateTime today) {
    final done = dailyDone();
    var d = done.containsKey(dateKey(today)) ? today : previousDay(today);
    var n = 0;
    while (done.containsKey(dateKey(d))) {
      n++;
      d = previousDay(d);
    }
    return n;
  }

  /// Chuoi dai nhat tung dat.
  int bestStreak() {
    final days = dailyDone().keys.map(parseDateKey).toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in days) {
      run = prev != null && previousDay(d) == prev ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  Future<void> resetAll() async {
    final keys = _prefs.getKeys().where(
      (k) =>
          k.startsWith(_statsPrefix) ||
          k.startsWith(_statePrefix) ||
          k == _dailyKey,
    );
    for (final k in keys.toList()) {
      await _prefs.remove(k);
    }
    version.value++;
  }
}

final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Ghi de sharedPrefsProvider trong main'),
);

final progressStoreProvider = Provider<ProgressStore>(
  (ref) => ProgressStore(ref.watch(sharedPrefsProvider)),
);

/// Giai ma luoi so nguyen tu JSON.
List<List<int>> decodeIntGrid(Object? o) => [
  for (final r in o! as List) (r as List).cast<int>().toList(),
];
