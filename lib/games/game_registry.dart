import 'package:flutter/material.dart';
import 'package:puzzle_hub/games/game2048/presentation/game2048_screen.dart';
import 'package:puzzle_hub/games/lights_out/presentation/lights_out_screen.dart';
import 'package:puzzle_hub/games/memory/presentation/memory_screen.dart';
import 'package:puzzle_hub/games/minesweeper/presentation/minesweeper_screen.dart';
import 'package:puzzle_hub/games/nonogram/presentation/nonogram_screen.dart';
import 'package:puzzle_hub/games/sliding/presentation/sliding_screen.dart';
import 'package:puzzle_hub/games/sudoku/presentation/sudoku_screen.dart';

/// Cach hien ky luc tren the game: diem, luot hoac giay.
enum BestKind { score, moves, seconds }

/// Moi game la mot muc trong registry; them game moi = them mot dong.
class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
    this.bestKind,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
  final BestKind? bestKind;

  String? bestLabel(int? best) {
    if (best == null || bestKind == null) return null;
    return switch (bestKind!) {
      BestKind.score => 'Kỷ lục $best điểm',
      BestKind.moves => 'Kỷ lục $best lượt',
      BestKind.seconds => 'Kỷ lục $best giây',
    };
  }
}

final gameRegistry = <GameInfo>[
  GameInfo(
    id: 'sudoku',
    title: 'Sudoku',
    subtitle: 'Điền số 1-9, không trùng hàng, cột, ô 3x3',
    icon: Icons.grid_on,
    builder: (_) => const SudokuScreen(),
  ),
  GameInfo(
    id: '2048',
    title: '2048',
    subtitle: 'Vuốt để gộp các ô giống nhau, chạm tới 2048',
    icon: Icons.apps,
    builder: (_) => const Game2048Screen(),
    bestKind: BestKind.score,
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
    bestKind: BestKind.moves,
  ),
  GameInfo(
    id: 'minesweeper',
    title: 'Dò mìn',
    subtitle: 'Mở hết ô an toàn, cắm cờ các ô có mìn',
    icon: Icons.flag_outlined,
    builder: (_) => const MinesweeperScreen(),
    bestKind: BestKind.seconds,
  ),
  GameInfo(
    id: 'lights_out',
    title: 'Tắt đèn',
    subtitle: 'Tắt hết đèn, mỗi lần bấm đảo cả ô kề bên',
    icon: Icons.lightbulb_outline,
    builder: (_) => const LightsOutScreen(),
    bestKind: BestKind.moves,
  ),
  GameInfo(
    id: 'sliding',
    title: 'Xếp số',
    subtitle: 'Trượt các ô để xếp số từ 1 đến 15',
    icon: Icons.view_module_outlined,
    builder: (_) => const SlidingScreen(),
    bestKind: BestKind.moves,
  ),
];
