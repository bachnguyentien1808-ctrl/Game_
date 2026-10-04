import 'dart:math';

import 'package:puzzle_hub/games/lights_out/domain/lights_out_engine.dart';
import 'package:puzzle_hub/games/lights_out/domain/lights_out_solver.dart';

/// Che do Man choi: 36 man tang dan, de cua tung man co dinh (seed theo so man).
abstract final class LightsOutLevels {
  /// So man theo kich thuoc 3x3, 4x4, 5x5, 6x6.
  static const _groups = <(int size, int count, int minPress, int maxPress)>[
    (3, 6, 2, 5),
    (4, 8, 3, 8),
    (5, 12, 4, 10),
    (6, 10, 5, 12),
  ];

  static final int count = _groups.fold(0, (a, g) => a + g.$2);

  /// (kich thuoc, so lan bam sinh de) cua man level (tinh tu 1).
  static (int, int) _config(int level) {
    assert(level >= 1 && level <= count, 'Man ngoai khoang');
    var left = level - 1;
    for (final (size, n, lo, hi) in _groups) {
      if (left < n) {
        final presses = n == 1 ? lo : lo + left * (hi - lo) ~/ (n - 1);
        return (size, presses);
      }
      left -= n;
    }
    throw RangeError.range(level, 1, count);
  }

  static int sizeOf(int level) => _config(level).$1;

  /// Dung de bang bam so lan presses o khac nhau tu bang tat het, nen luon giai duoc
  /// va toi uu <= presses.
  static LightsOut build(int level) {
    final (size, presses) = _config(level);
    final rng = Random(level * 10007 + 97);
    final v = size * size;
    while (true) {
      final cells = List.generate(size, (_) => List.filled(size, false));
      final order = List.generate(v, (i) => i)..shuffle(rng);
      for (final i in order.take(presses)) {
        pressCells(cells, i ~/ size, i % size);
      }
      if (cells.any((r) => r.any((x) => x))) return LightsOut(cells);
    }
  }

  /// 3 sao neu <= toi uu, 2 sao neu <= toi uu + 3, con lai 1 sao.
  static int stars(int moves, int optimal) {
    if (moves <= optimal) return 3;
    if (moves <= optimal + 3) return 2;
    return 1;
  }
}
