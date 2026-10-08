import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzle_hub/features/common/hub_panels.dart';

/// Cau dong vien o goc duoi ben trai cua tung game.
const gameQuotes = <String, String>{
  'sudoku': 'Mỗi con số đúng là một bước tiến gần hơn đến chiến thắng.',
  '2048': 'Mỗi lần gộp ô là một bước gần hơn tới con số 2048.',
  'nonogram': 'Từng ô nhỏ ghép lại sẽ thành một bức tranh trọn vẹn.',
  'memory': 'Nhớ thật kỹ, mỗi cặp ghép đúng là một niềm vui nhỏ.',
  'minesweeper': 'Bình tĩnh suy luận, mỗi lá cờ đúng là một chiến thắng nhỏ.',
  'lights_out': 'Thắp sáng từng ô một, cả bàn cờ sẽ sáng lên.',
  'sliding': 'Từng bước nhỏ đưa mỗi con số về đúng chỗ của nó.',
  'kakuro': 'Mỗi tổng đúng là một mảnh ghép hoàn hảo.',
};

/// Be rong cot choi: man cao thi ban choi to len (toi da 760), dien thoai van
/// theo be rong man hinh. [base] la be rong goc cua game.
double playColumnWidth(BuildContext context, double base) {
  final h = MediaQuery.sizeOf(context).height;
  // Tru thanh tieu de, dau khoi, thanh thong tin va cac nut o duoi ban choi.
  return max(base, min<double>(760, h - 420));
}

/// Be rong cot choi vua phai cho cac game khac Sudoku: to hon be rong goc mot
/// chut khi man cao, khong qua to.
double modestColumnWidth(BuildContext context, double base) {
  final h = MediaQuery.sizeOf(context).height;
  return max(base, min(base + 60, h - 380));
}

/// Be rong cot choi to theo chieu cao man hinh nhung van ke tru phan phu
/// ([chrome]: dau khoi, thanh thong tin, nut): toi thieu [base], toi da [max].
double fitColumnWidth(
  BuildContext context,
  double base, {
  required double max,
  double chrome = 340,
}) {
  final h = MediaQuery.sizeOf(context).height;
  return _maxOf(base, _minOf(max, h - chrome));
}

double _maxOf(double a, double b) => a > b ? a : b;
double _minOf(double a, double b) => a < b ? a : b;

/// Lop phu chung cua man choi: cau noi o goc duoi ben trai va bang Thanh tich
/// o goc tren ben phai, chi hien khi hai ben ban choi con du cho.
class GameOverlays extends StatelessWidget {
  const GameOverlays({required this.gameId, required this.child, super.key});

  final String gameId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Be rong uoc luong cua khung choi: Sudoku to len theo chieu cao, Nonogram
    // rong nhat, cac game khac giu be rong goc.
    final content = switch (gameId) {
      'sudoku' => playColumnWidth(context, 480),
      'nonogram' => 1000.0,
      '2048' => 720.0,
      'memory' => 840.0,
      'lights_out' => 760.0,
      'sliding' => 650.0,
      'minesweeper' => 900.0,
      _ => 560.0,
    };
    final sideRoom = (size.width - content) / 2;
    final quote = gameQuotes[gameId];
    return Stack(
      children: [
        child,
        if (quote != null && sideRoom >= 200)
          Positioned(
            left: 24,
            bottom: 20,
            width: min<double>(300, sideRoom - 40),
            child: IgnorePointer(child: _Quote(quote)),
          ),
        if (sideRoom >= 300)
          Positioned(
            top: kToolbarHeight + 8,
            right: 12,
            width: 280,
            child: AchievementsPanel(gameId: gameId),
          ),
      ],
    );
  }
}

/// Cau noi co vach doc ben trai.
class _Quote extends StatelessWidget {
  const _Quote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xCCFFFFFF), width: 2)),
        ),
        child: Text(
          '“$text”',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w500,
            shadows: [Shadow(color: Color(0xCC000000), blurRadius: 5)],
          ),
        ),
      ),
    );
  }
}
