import 'dart:math';

import 'package:puzzle_hub/core/daily/daily_challenge.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';

/// Bo boc [ProgressStore] cho mot man game. Cung API nhu ProgressStore, nhung
/// khi [daily] != null (che do thu thach ngay):
/// - trang thai luu o khoa rieng `daily.<id>.<yyyyMMdd>`, khong dung ván thuong;
/// - recordStart/recordScore bi bo qua, recordWin danh dau hoan thanh ngay do;
/// - [rngFor] tra Random co seed co dinh de moi may sinh cung mot de.
class GameStore {
  GameStore(this._s, {this.daily});

  final ProgressStore _s;

  /// Khoa ngay yyyyMMdd neu dang o che do thu thach ngay.
  final String? daily;

  bool get isDaily => daily != null;

  /// Route de quay ve khi bam nut Back.
  String get homeRoute => isDaily ? '/daily' : '/';

  String _key(String id) => isDaily ? 'daily.$id.$daily' : id;

  /// Random co seed (che do ngay) hoac null (che do thuong -> engine tu chon).
  Random? rngFor(String id) => isDaily ? Random(dailySeed(daily!, id)) : null;

  GameStats stats(String id) => _s.stats(id);

  Future<void> recordStart(String id) =>
      isDaily ? Future.value() : _s.recordStart(id);

  Future<void> recordWin(String id, {int? score, bool lowerIsBetter = false}) =>
      isDaily
      ? _s.completeDaily(daily!, score: score)
      : _s.recordWin(id, score: score, lowerIsBetter: lowerIsBetter);

  Future<void> recordScore(
    String id,
    int score, {
    bool lowerIsBetter = false,
  }) => isDaily
      ? Future.value()
      : _s.recordScore(id, score, lowerIsBetter: lowerIsBetter);

  Map<String, dynamic>? loadState(String id) => _s.loadState(_key(id));

  Future<void> saveState(String id, Map<String, dynamic> state) =>
      _s.saveState(_key(id), state);

  Future<void> clearState(String id) => _s.clearState(_key(id));
}
