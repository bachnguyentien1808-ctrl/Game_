import 'package:flutter/material.dart';
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
    subtitle: 'Điền số 1-9, không trùng hàng, cột, ô 3x3',
    icon: Icons.grid_on,
    builder: (_) => const SudokuScreen(),
  ),
];
