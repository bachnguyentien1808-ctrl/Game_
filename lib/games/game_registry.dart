import 'package:flutter/material.dart';
import 'package:puzzle_hub/games/game2048/presentation/game2048_screen.dart';
import 'package:puzzle_hub/games/memory/presentation/memory_screen.dart';
import 'package:puzzle_hub/games/nonogram/presentation/nonogram_screen.dart';
import 'package:puzzle_hub/games/sudoku/presentation/sudoku_screen.dart';

/// Moi game la mot muc trong registry; them game moi = them mot dong.
class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}

final gameRegistry = <GameInfo>[
  GameInfo(
    id: 'sudoku',
    title: 'Sudoku',
    subtitle: 'Äiá»n sá»‘ 1-9, khÃ´ng trÃ¹ng hÃ ng, cá»™t, Ã´ 3x3',
    icon: Icons.grid_on,
    builder: (_) => const SudokuScreen(),
  ),
  GameInfo(
    id: '2048',
    title: '2048',
    subtitle: 'Vuốt để gộp các ô giống nhau, chạm tới 2048',
    icon: Icons.apps,
    builder: (_) => const Game2048Screen(),
  ),
  GameInfo(
    id: 'nonogram',
    title: 'Nonogram',
    subtitle: 'Tô ô theo gợi ý số để hiện bức tranh ẩn',
    icon: Icons.image_outlined,
    builder: (_) => const NonogramScreen(),
  ),
  GameInfo(
    id: 'memory',
    title: 'Tìm cặp',
    subtitle: 'Lật thẻ và ghi nhớ vị trí để ghép đủ các cặp',
    icon: Icons.style,
    builder: (_) => const MemoryScreen(),
  ),
];
