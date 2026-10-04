import 'dart:math';

class MemoryCard {
  MemoryCard(this.id, this.symbol);

  final int id;
  final int symbol;
  bool faceUp = false;
  bool matched = false;
}

class MemoryGame {
  MemoryGame({int pairs = 8, Random? rng}) {
    final symbols = [
      for (var i = 0; i < pairs; i++) ...[i, i],
    ]..shuffle(rng ?? Random());
    cards = [
      for (var i = 0; i < symbols.length; i++) MemoryCard(i, symbols[i]),
    ];
  }

  /// Khoi phuc van dang choi; cap chua ghep xuat hien lai la up.
  MemoryGame.restore({
    required List<int> symbols,
    required List<bool> matched,
    required this.moves,
  }) {
    cards = [
      for (var i = 0; i < symbols.length; i++)
        MemoryCard(i, symbols[i])..matched = matched[i],
    ];
  }

  factory MemoryGame.fromJson(Map<String, dynamic> j) => MemoryGame.restore(
    symbols: (j['symbols'] as List).cast<int>(),
    matched: (j['matched'] as List).cast<bool>(),
    moves: j['moves'] as int,
  );

  late final List<MemoryCard> cards;
  int moves = 0;
  final List<MemoryCard> _open = [];

  Map<String, dynamic> toJson() => {
    'symbols': [for (final c in cards) c.symbol],
    'matched': [for (final c in cards) c.matched],
    'moves': moves,
  };

  bool get won => cards.every((c) => c.matched);

  /// Dang cho lat lai cap sai (UI goi [hideMismatch] sau mot nhip).
  bool get waiting => _open.length == 2;

  void flip(int index) {
    final card = cards[index];
    if (waiting || card.faceUp || card.matched) return;
    card.faceUp = true;
    _open.add(card);
    if (_open.length == 2) {
      moves++;
      if (_open[0].symbol == _open[1].symbol) {
        _open[0].matched = _open[1].matched = true;
        _open.clear();
      }
    }
  }

  void hideMismatch() {
    for (final c in _open) {
      c.faceUp = false;
    }
    _open.clear();
  }
}
