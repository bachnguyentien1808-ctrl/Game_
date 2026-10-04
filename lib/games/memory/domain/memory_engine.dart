import 'dart:math';

/// Kich thuoc ban (cot x hang).
enum MemorySize {
  s3x4(3, 4, '3x4'),
  s4x4(4, 4, '4x4'),
  s5x4(5, 4, '5x4'),
  s6x6(6, 6, '6x6');

  MemorySize(this.cols, this.rows, this.label);

  final int cols;
  final int rows;
  final String label;

  int get cells => cols * rows;
  int get pairs => cells ~/ 2;

  /// Khoa thong ke rieng cho tung kich thuoc, vd 'memory.4x4'.
  String get statsId => 'memory.$label';

  static MemorySize fromLabel(String? l) => MemorySize.values.firstWhere(
    (s) => s.label == l,
    orElse: () => MemorySize.s4x4,
  );
}

/// Bo hinh: moi bo co du 18 hinh khac nhau (du cho 6x6).
enum MemorySet {
  icons('Biểu tượng'),
  shapes('Hình học'),
  letters('Chữ cái');

  MemorySet(this.title);

  final String title;

  static const int symbolCount = 18;

  static MemorySet fromName(String? n) => MemorySet.values.firstWhere(
    (s) => s.name == n,
    orElse: () => MemorySet.icons,
  );
}

enum FlipResult { ignored, first, match, mismatch }

class MemoryCard {
  MemoryCard(this.id, this.symbol);

  final int id;
  final int symbol;
  bool faceUp = false;
  bool matched = false;
}

class MemoryGame {
  MemoryGame({
    this.size = MemorySize.s4x4,
    this.set = MemorySet.icons,
    Random? rng,
  }) {
    final symbols = [
      for (var i = 0; i < size.pairs; i++) ...[i, i],
    ]..shuffle(rng ?? Random());
    cards = [
      for (var i = 0; i < symbols.length; i++) MemoryCard(i, symbols[i]),
    ];
  }

  /// Khoi phuc van dang choi; cap chua ghep xuat hien lai la up.
  MemoryGame.restore({
    required this.size,
    required this.set,
    required List<int> symbols,
    required List<bool> matched,
    this.moves = 0,
    this.combo = 0,
    this.bestCombo = 0,
    this.seconds = 0,
    this.peeksUsed = 0,
  }) {
    if (symbols.length != size.cells || matched.length != size.cells) {
      throw const FormatException('sai kich thuoc');
    }
    if (symbols.any((s) => s < 0 || s >= size.pairs)) {
      throw const FormatException('sai hinh');
    }
    cards = [
      for (var i = 0; i < symbols.length; i++)
        MemoryCard(i, symbols[i])..matched = matched[i],
    ];
  }

  factory MemoryGame.fromJson(Map<String, dynamic> j) => MemoryGame.restore(
    size: MemorySize.fromLabel(j['size'] as String?),
    set: MemorySet.fromName(j['set'] as String?),
    symbols: (j['symbols'] as List).cast<int>(),
    matched: (j['matched'] as List).cast<bool>(),
    moves: j['moves'] as int? ?? 0,
    combo: j['combo'] as int? ?? 0,
    bestCombo: j['bestCombo'] as int? ?? 0,
    seconds: j['seconds'] as int? ?? 0,
    peeksUsed: j['peeks'] as int? ?? 0,
  );

  static const int maxPeeks = 2;

  final MemorySize size;
  final MemorySet set;
  late final List<MemoryCard> cards;
  int moves = 0;
  int combo = 0;
  int bestCombo = 0;
  int seconds = 0;
  int peeksUsed = 0;
  final List<MemoryCard> _open = [];

  Map<String, dynamic> toJson() => {
    'size': size.label,
    'set': set.name,
    'symbols': [for (final c in cards) c.symbol],
    'matched': [for (final c in cards) c.matched],
    'moves': moves,
    'combo': combo,
    'bestCombo': bestCombo,
    'seconds': seconds,
    'peeks': peeksUsed,
  };

  bool get won => cards.every((c) => c.matched);

  int get matchedPairs => cards.where((c) => c.matched).length ~/ 2;

  int get peeksLeft => maxPeeks - peeksUsed;

  /// Dang cho lat lai cap sai (UI goi [hideMismatch] sau mot nhip).
  bool get waiting => _open.length == 2;

  /// Da bat dau lat the nao chua (de tinh dong ho / thong ke).
  bool get started => moves > 0 || _open.isNotEmpty;

  FlipResult flip(int index) {
    final card = cards[index];
    if (waiting || card.faceUp || card.matched) return FlipResult.ignored;
    card.faceUp = true;
    _open.add(card);
    if (_open.length < 2) return FlipResult.first;
    moves++;
    if (_open[0].symbol == _open[1].symbol) {
      _open[0].matched = _open[1].matched = true;
      for (final c in _open) {
        c.faceUp = false;
      }
      _open.clear();
      combo++;
      bestCombo = max(bestCombo, combo);
      return FlipResult.match;
    }
    combo = 0;
    return FlipResult.mismatch;
  }

  void hideMismatch() {
    for (final c in _open) {
      c.faceUp = false;
    }
    _open.clear();
  }

  /// Dung mot luot "Nhin truoc"; false neu het luot.
  bool usePeek() {
    if (peeksLeft <= 0 || won) return false;
    peeksUsed++;
    return true;
  }

  /// Sao 1-3 theo so luot va thoi gian.
  static int starsFor(MemorySize size, int moves, int seconds) {
    final p = size.pairs;
    var stars = moves <= (p * 1.6).ceil()
        ? 3
        : moves <= (p * 2.5).ceil()
        ? 2
        : 1;
    if (seconds > p * 12 && stars > 1) stars--;
    return stars;
  }

  int get stars => starsFor(size, moves, seconds);
}
