import 'package:flutter/material.dart';
import 'package:puzzle_hub/games/game2048/presentation/game2048_screen.dart';
import 'package:puzzle_hub/games/kakuro/presentation/kakuro_screen.dart';
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
    this.dailyBuilder,
    this.howTo,
  });

  final String id;

  /// Co gia tri neu game ho tro Thu thach moi ngay: nhan khoa ngay yyyyMMdd.
  final Widget Function(String dateKey)? dailyBuilder;

  /// Huong dan cach choi ngan (hien o man Cach choi).
  final String? howTo;
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
    dailyBuilder: (d) => SudokuScreen(daily: d),
    bestKind: BestKind.seconds,
    howTo:
        'Điền số 1-9 vào mỗi ô trống sao cho mỗi hàng, mỗi cột và mỗi khối '
        '3x3 đều có đủ chín số, không trùng. Chạm một ô rồi chọn số ở bàn '
        'phím bên dưới; bật Ghi chú để viết số nháp nhỏ trong ô. Sai quá 3 '
        'lần là thua (có thể tắt trong menu). Gợi ý có giới hạn sẽ giải '
        'thích vì sao ô đó phải là số ấy.',
  ),
  GameInfo(
    id: '2048',
    title: '2048',
    subtitle: 'Vuốt để gộp các ô giống nhau, chạm tới 2048',
    icon: Icons.apps,
    builder: (_) => const Game2048Screen(),
    bestKind: BestKind.score,
    howTo:
        'Vuốt (hoặc phím mũi tên / WASD) để trượt mọi ô. Hai ô cùng số chạm nhau '
        'thì gộp thành ô gấp đôi và cộng điểm; mỗi ô chỉ gộp một lần mỗi nước. '
        'Mỗi nước sinh thêm một ô 2 hoặc 4. Chạm ô 2048 là thắng (có thể chơi '
        'tiếp), hết nước đi là thua. Có 3 lần hoàn tác mỗi ván; chọn bàn 3x3, '
        '4x4 hoặc 5x5, kỷ lục tính riêng từng cỡ.',
  ),
  GameInfo(
    id: 'nonogram',
    title: 'Nonogram',
    subtitle: 'Tô ô theo gợi ý số để hiện bức tranh ẩn',
    icon: Icons.image_outlined,
    builder: (_) => const NonogramScreen(),
    howTo:
        'Số bên trái và phía trên cho biết các đoạn ô liên tiếp cần tô trong '
        'hàng/cột đó, theo thứ tự. Chọn Tô hoặc X rồi chạm hoặc kéo ngón tay '
        'dọc một hàng/cột để tô hàng loạt. Gợi ý mờ đi khi đoạn đã đủ. Bật '
        'Kiểm tra lỗi để thấy ô sai, dùng Xem để phóng to bằng hai ngón. '
        'Giải xong tranh sẽ hiện màu; sao tính theo thời gian, lỗi và gợi ý.',
  ),
  GameInfo(
    id: 'memory',
    title: 'Tìm cặp',
    subtitle: 'Lật thẻ và ghi nhớ vị trí để ghép đủ các cặp',
    icon: Icons.style,
    builder: (_) => const MemoryScreen(),
    dailyBuilder: (d) => MemoryScreen(daily: d),
    bestKind: BestKind.moves,
    howTo: 'Chạm để lật hai thẻ mỗi lượt, ghép các cặp hình giống nhau. Ghép đúng thì thẻ sáng lên và tính chuỗi liên tiếp, sai thì thẻ úp lại. Chọn kích thước (3x4 tới 6x6) và bộ hình trước khi chơi. Nút Nhìn trước cho xem toàn bàn vài giây (tối đa 2 lần). Ít lượt và nhanh thì được nhiều sao hơn.',
  ),
  GameInfo(
    id: 'minesweeper',
    title: 'Dò mìn',
    subtitle: 'Mở hết ô an toàn, cắm cờ các ô có mìn',
    icon: Icons.flag_outlined,
    builder: (_) => const MinesweeperScreen(),
    dailyBuilder: (d) => MinesweeperScreen(daily: d),
    howTo:
        'Chạm để mở ô; số trên ô là số mìn ở 8 ô xung quanh. Nhấn giữ (hoặc '
        'chuột phải, hoặc chế độ Cắm cờ) để cắm cờ lên ô nghi có mìn. Chạm vào '
        'số đã đủ cờ để mở nhanh các ô kề. Lượt mở đầu luôn an toàn. Có 3 lượt '
        'gợi ý mỗi ván (chỉ ra một ô chắc chắn an toàn nếu suy ra được). Chọn '
        'Dễ, Vừa, Khó hoặc Tuỳ chỉnh ở biểu tượng chỉnh; mỗi mức có kỷ lục riêng. '
        'Mở hết ô an toàn là thắng.',
    bestKind: BestKind.seconds,
  ),
  GameInfo(
    id: 'lights_out',
    title: 'Tắt đèn',
    subtitle: 'Tắt hết đèn, mỗi lần bấm đảo cả ô kề bên',
    icon: Icons.lightbulb_outline,
    builder: (_) => const LightsOutScreen(),
    dailyBuilder: (d) => LightsOutScreen(daily: d),
    howTo:
        'Bấm một ô sẽ đảo trạng thái ô đó và 4 ô kề bên (trên, dưới, trái, phải). '
        'Mục tiêu: tắt hết đèn với ít lượt nhất. Chế độ Màn chơi có 36 màn từ 3x3 đến 6x6, '
        'đạt 3 sao khi số lượt không vượt mức tối ưu (2 sao nếu hơn tối đa 3 lượt). '
        'Dùng Hoàn tác/Làm lại để thử hướng khác và Gợi ý (3 lần mỗi ván) để biết ô nên bấm tiếp.',
    bestKind: BestKind.moves,
  ),
  GameInfo(
    id: 'sliding',
    title: 'Xếp số',
    subtitle: 'Trượt các ô để xếp số hoặc ghép tranh, 3x3 đến 5x5',
    icon: Icons.view_module_outlined,
    builder: (_) => const SlidingScreen(),
    dailyBuilder: (d) => SlidingScreen(daily: d),
    bestKind: BestKind.moves,
    howTo:
        'Chạm một ô để trượt nó vào chỗ trống; chạm ô ở xa thì cả hàng hoặc '
        'cột trượt theo. Cũng có thể vuốt theo hướng muốn trượt. Xếp các số '
        'từ nhỏ đến lớn, ô trống ở góc dưới phải. Chế độ Ảnh: ghép lại bức '
        'tranh, giữ nút mắt để xem bản gốc. Có hoàn tác, tạm dừng và 3 gợi ý '
        'mỗi ván; kỷ lục tính riêng cho từng kích thước.',
  ),
  GameInfo(
    id: 'kakuro',
    title: 'Kakuro',
    subtitle: 'Điền số 1-9 sao cho mỗi đoạn cộng đúng tổng gợi ý',
    icon: Icons.calculate_outlined,
    builder: (_) => const KakuroScreen(),
    dailyBuilder: (d) => KakuroScreen(daily: d),
    bestKind: BestKind.seconds,
    howTo:
        'Ô tối có đường chéo là ô gợi ý: số góc trên-phải là tổng các ô trắng '
        'liền bên phải, số góc dưới-trái là tổng các ô trắng liền bên dưới. '
        'Điền chữ số 1-9 vào ô trắng; trong mỗi đoạn các số không được trùng '
        'và phải cộng đúng tổng. Đoạn đúng tô xanh, ô lỗi tô đỏ. Có ghi chú '
        'bút chì, hoàn tác và vài lượt gợi ý; kỷ lục thời gian tính theo mức.',
  ),
];
