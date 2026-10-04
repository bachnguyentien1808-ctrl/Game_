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

  late final List<MemoryCard> cards;
  int moves = 0;
  final List<MemoryCard> _open = [];

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
