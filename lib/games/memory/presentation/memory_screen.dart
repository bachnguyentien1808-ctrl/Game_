import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/games/memory/domain/memory_engine.dart';

const _icons = <IconData>[
  Icons.pets,
  Icons.rocket_launch,
  Icons.favorite,
  Icons.star,
  Icons.eco,
  Icons.cake,
  Icons.anchor,
  Icons.bolt,
];

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  MemoryGame _game = MemoryGame();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _flip(int i) {
    setState(() => _game.flip(i));
    if (_game.waiting) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(_game.hideMismatch);
      });
    }
  }

  void _restart() {
    _timer?.cancel();
    setState(() => _game = MemoryGame());
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(_game.won ? 'Tìm cặp - Thắng!' : 'Tìm cặp'),
        actions: [
          IconButton(
            tooltip: 'Ván mới',
            icon: const Icon(Icons.refresh),
            onPressed: _restart,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Số lượt: ${_game.moves}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 1,
                  child: GridView.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < _game.cards.length; i++)
                        _card(_game.cards[i], i, s),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(MemoryCard c, int i, ColorScheme s) {
    final show = c.faceUp || c.matched;
    return GestureDetector(
      onTap: () => _flip(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: c.matched
              ? s.tertiaryContainer
              : show
              ? s.primaryContainer
              : s.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: show
            ? Icon(_icons[c.symbol], size: 36, color: s.onPrimaryContainer)
            : Icon(Icons.psychology_alt, color: s.onPrimary),
      ),
    );
  }
}
