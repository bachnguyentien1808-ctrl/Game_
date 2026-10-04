/// Van dang choi do cua mot tranh.
class LevelSave {
  LevelSave({
    required this.grid,
    this.seconds = 0,
    this.hints = 0,
    this.mistakes = 0,
    this.locked = const [],
  });

  final List<List<int>> grid;
  final int seconds;
  final int hints;
  final int mistakes;

  /// Cac o bi khoa do goi y, ma hoa r*size+c.
  final List<int> locked;

  Map<String, dynamic> toJson() => {
    'g': grid,
    't': seconds,
    'h': hints,
    'm': mistakes,
    'l': locked,
  };

  static LevelSave? fromJson(Object? o, int size) {
    try {
      final j = o! as Map;
      final g = [
        for (final r in j['g'] as List) (r as List).cast<int>().toList(),
      ];
      if (g.length != size || g.any((r) => r.length != size)) return null;
      return LevelSave(
        grid: g,
        seconds: (j['t'] as int?) ?? 0,
        hints: (j['h'] as int?) ?? 0,
        mistakes: (j['m'] as int?) ?? 0,
        locked: ((j['l'] as List?) ?? const []).cast<int>().toList(),
      );
    } on Object {
      return null;
    }
  }
}

/// Ky luc cua mot tranh da giai.
typedef LevelBest = ({int seconds, int stars});

/// Toan bo tien do nonogram (luu qua GameStore, khoa 'nonogram').
class NonogramProgress {
  NonogramProgress();

  /// [sizeOf] tra kich thuoc tranh theo chi so (null neu chi so khong hop le).
  factory NonogramProgress.fromJson(
    Map<String, dynamic>? j,
    int? Function(int index) sizeOf,
  ) {
    final p = NonogramProgress();
    if (j == null || j['v'] != 2) return p;
    try {
      for (final e in (j['saves'] as Map).entries) {
        final i = int.parse(e.key as String);
        final size = sizeOf(i);
        if (size == null) continue;
        final s = LevelSave.fromJson(e.value, size);
        if (s != null) p.saves[i] = s;
      }
      for (final e in (j['best'] as Map).entries) {
        final i = int.parse(e.key as String);
        if (sizeOf(i) == null) continue;
        final m = e.value as Map;
        p.best[i] = (seconds: m['t'] as int, stars: m['s'] as int);
      }
    } on Object {
      // du lieu hong -> giu phan doc duoc
    }
    return p;
  }

  /// Van do theo chi so tranh.
  final Map<int, LevelSave> saves = {};

  /// Ky luc theo chi so tranh (co mat = da giai).
  final Map<int, LevelBest> best = {};

  bool isSolved(int i) => best.containsKey(i);

  int solvedIn(Iterable<int> indices) => indices.where(isSolved).length;

  /// Ghi nhan thang; tra true neu la ky luc moi (nhanh hon hoac nhieu sao hon).
  bool recordWin(int i, int seconds, int stars) {
    final old = best[i];
    saves.remove(i);
    if (old == null || seconds < old.seconds) {
      best[i] = (
        seconds: seconds,
        stars: stars > (old?.stars ?? 0) ? stars : (old?.stars ?? stars),
      );
      return true;
    }
    if (stars > old.stars) best[i] = (seconds: old.seconds, stars: stars);
    return false;
  }

  Map<String, dynamic> toJson() => {
    'v': 2,
    'saves': {for (final e in saves.entries) '${e.key}': e.value.toJson()},
    'best': {
      for (final e in best.entries)
        '${e.key}': {'t': e.value.seconds, 's': e.value.stars},
    },
  };
}
