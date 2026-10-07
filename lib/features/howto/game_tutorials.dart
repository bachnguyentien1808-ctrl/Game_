import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

/// Mot buoc huong dan: icon lon, tieu de, noi dung ngan.
class TutorialStep {
  const TutorialStep(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;
}

/// Mot dong chu thich: hinh nho + y nghia.
class LegendItem {
  const LegendItem(this.leading, this.label);

  final Widget leading;
  final String label;
}

class GameTutorial {
  const GameTutorial({required this.steps, required this.legend, this.tip});

  final List<TutorialStep> steps;
  final List<LegendItem> legend;

  /// Meo nho hien o cuoi trang chu thich.
  final String? tip;
}

Widget _icon(IconData i, [Color c = Colors.white70]) =>
    Icon(i, color: c, size: 26);

Widget _tile(List<Color> g, {Widget? child}) => Container(
  width: 28,
  height: 28,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(7),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: g,
    ),
  ),
  child: child,
);

Widget _num(String t, Color c) => SizedBox(
  width: 28,
  child: Center(
    child: Text(
      t,
      style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 20),
    ),
  ),
);

const _cream = [Color(0xFFFFF4DC), Color(0xFFF6DBAA)];

/// Huong dan + chu thich cho tung game, khoa theo `GameInfo.id`.
final Map<String, GameTutorial> gameTutorials = {
  'sudoku': GameTutorial(
    steps: const [
      TutorialStep(
        Icons.grid_on,
        'Mục tiêu',
        'Điền các số 1-9 vào ô trống sao cho mỗi hàng, mỗi cột và mỗi khối '
            '3x3 đều có đủ chín số, không trùng nhau.',
      ),
      TutorialStep(
        Icons.touch_app,
        'Cách điền',
        'Chạm vào một ô trống, rồi chọn số ở bàn phím bên dưới.',
      ),
      TutorialStep(
        Icons.edit_note,
        'Ghi chú nháp',
        'Chưa chắc chắn? Bật Ghi chú để viết nhiều số nhỏ vào cùng một ô, '
            'rồi loại dần cho đến khi còn một số.',
      ),
      TutorialStep(
        Icons.lightbulb_outline,
        'Gợi ý và lỗi',
        'Gợi ý có giới hạn và sẽ giải thích vì sao ô đó phải là số ấy. Điền '
            'sai quá 3 lần là thua (có thể tắt trong menu).',
      ),
    ],
    legend: [
      LegendItem(_icon(Icons.edit_note), 'Ghi chú: số nháp nhỏ trong ô'),
      LegendItem(_icon(Icons.lightbulb_outline), 'Gợi ý kèm giải thích'),
      LegendItem(_icon(Icons.undo), 'Hoàn tác nước vừa đi'),
      LegendItem(_icon(Icons.pause_circle_outline), 'Tạm dừng đồng hồ'),
    ],
    tip: 'Bắt đầu từ hàng, cột hoặc khối đã có nhiều số nhất.',
  ),
  '2048': GameTutorial(
    steps: const [
      TutorialStep(
        Icons.swipe,
        'Vuốt để trượt',
        'Vuốt lên, xuống, trái, phải (hoặc dùng phím mũi tên, WASD) để trượt '
            'mọi ô cùng lúc.',
      ),
      TutorialStep(
        Icons.merge_type,
        'Gộp số',
        'Hai ô cùng số chạm nhau sẽ gộp thành ô gấp đôi và cộng điểm. Mỗi '
            'ô chỉ gộp một lần mỗi nước.',
      ),
      TutorialStep(
        Icons.emoji_events_outlined,
        'Thắng và thua',
        'Tạo được ô 2048 là thắng (vẫn chơi tiếp được). Hết chỗ trống và '
            'không gộp được nữa là thua.',
      ),
    ],
    legend: [
      LegendItem(_icon(Icons.undo), 'Hoàn tác (3 lần mỗi ván)'),
      LegendItem(_icon(Icons.refresh), 'Ván mới'),
      LegendItem(_icon(Icons.grid_4x4), 'Đổi cỡ bàn 3x3, 4x4, 5x5'),
    ],
    tip: 'Giữ ô lớn nhất ở một góc và đừng vuốt ngược lại nếu không cần.',
  ),
  'nonogram': GameTutorial(
    steps: const [
      TutorialStep(
        Icons.looks_one_outlined,
        'Đọc số gợi ý',
        'Số bên trái và phía trên cho biết các đoạn ô liên tiếp phải tô '
            'trong hàng hoặc cột đó, theo đúng thứ tự. Ví dụ "3 1" là một '
            'đoạn 3 ô, cách ít nhất một ô trống, rồi 1 ô.',
      ),
      TutorialStep(
        Icons.brush,
        'Tô và đánh dấu X',
        'Chọn Tô để tô ô, hoặc X để đánh dấu ô chắc chắn trống. Kéo ngón '
            'tay dọc một hàng hoặc cột để tô hàng loạt.',
      ),
      TutorialStep(
        Icons.image_outlined,
        'Hoàn thành tranh',
        'Khớp mọi hàng và cột là giải xong, bức tranh sẽ hiện màu. Sao '
            'thưởng tính theo thời gian, lỗi và số lần gợi ý.',
      ),
    ],
    legend: [
      LegendItem(
        _tile(const [Color(0xFF7C4DFF), Color(0xFF536DFE)]),
        'Ô đã tô',
      ),
      LegendItem(_icon(Icons.close), 'Ô đã đánh dấu trống (X)'),
      LegendItem(_icon(Icons.zoom_in), 'Xem: phóng to bằng hai ngón'),
      LegendItem(_icon(Icons.rule), 'Kiểm tra lỗi: hiện ô sai'),
    ],
    tip: 'Số mờ đi khi đoạn đó đã đủ. Hàng có số lớn thường giải trước.',
  ),
  'memory': GameTutorial(
    steps: const [
      TutorialStep(
        Icons.style,
        'Lật thẻ',
        'Mỗi lượt chạm lật hai thẻ. Nếu hai hình giống nhau thì thẻ sáng '
            'lên và được giữ lại; khác nhau thì úp lại.',
      ),
      TutorialStep(
        Icons.local_fire_department_outlined,
        'Chuỗi liên tiếp',
        'Ghép đúng nhiều lần liền nhau sẽ tạo chuỗi. Ít lượt và nhanh thì '
            'được nhiều sao hơn.',
      ),
      TutorialStep(
        Icons.visibility_outlined,
        'Nhìn trước',
        'Nút Nhìn trước cho xem toàn bàn vài giây, tối đa 2 lần mỗi ván. '
            'Chọn kích thước (3x4 tới 6x6) và bộ hình trước khi chơi.',
      ),
    ],
    legend: [
      LegendItem(_icon(Icons.visibility_outlined), 'Nhìn trước toàn bàn'),
      LegendItem(_icon(Icons.refresh), 'Ván mới'),
      LegendItem(_icon(Icons.star_rounded, Colors.amber), 'Sao thưởng'),
    ],
    tip: 'Nhớ vị trí các thẻ ở rìa trước, rồi mới tới giữa bàn.',
  ),
  'minesweeper': GameTutorial(
    steps: const [
      TutorialStep(
        Icons.touch_app,
        'Mở ô',
        'Chạm vào ô để mở. Lượt mở đầu luôn an toàn. Mở hết mọi ô không '
            'có mìn là thắng; mở trúng mìn là thua.',
      ),
      TutorialStep(
        Icons.pin_outlined,
        'Đọc con số',
        'Số trên ô cho biết có bao nhiêu mìn trong 8 ô xung quanh nó. Số 1 '
            'là có đúng một mìn kề bên.',
      ),
      TutorialStep(
        Icons.flag,
        'Cắm cờ',
        'Nhấn giữ ô (hoặc chọn nút Cắm cờ) để đánh dấu ô chắc có mìn. '
            'Chạm vào số đã đủ cờ để mở nhanh các ô kề.',
      ),
      TutorialStep(
        Icons.lightbulb_outline,
        'Gợi ý',
        'Có 3 lượt gợi ý mỗi ván, chỉ ra một ô chắc chắn an toàn nếu suy '
            'ra được. Đổi độ khó ở biểu tượng chỉnh góc trên.',
      ),
    ],
    legend: [
      LegendItem(
        _tile(Candy.blue),
        'Ô chưa mở (xanh dương hoặc xanh lá xen kẽ)',
      ),
      LegendItem(_tile(_cream), 'Ô đã mở, không có mìn'),
      LegendItem(_icon(Icons.flag, Colors.redAccent), 'Cờ: nghi có mìn'),
      LegendItem(
        _tile(Candy.red, child: _icon(Icons.brightness_7, Colors.white)),
        'Mìn (hiện khi thua)',
      ),
      LegendItem(_num('1', const Color(0xFF1565C0)), '1 mìn ở các ô kề'),
      LegendItem(_num('3', const Color(0xFFD32F2F)), '3 mìn ở các ô kề'),
    ],
    tip: 'Số 1 chỉ còn một ô chưa mở kề bên thì ô đó chắc chắn là mìn.',
  ),
  'lights_out': GameTutorial(
    steps: const [
      TutorialStep(
        Icons.lightbulb,
        'Bấm để đảo đèn',
        'Bấm một ô sẽ đảo trạng thái (sáng thành tắt, tắt thành sáng) của '
            'chính ô đó và 4 ô kề bên: trên, dưới, trái, phải.',
      ),
      TutorialStep(
        Icons.power_settings_new,
        'Mục tiêu',
        'Tắt hết đèn với ít lượt nhất có thể.',
      ),
      TutorialStep(
        Icons.star_rounded,
        'Sao thưởng',
        'Chế độ Màn chơi có 36 màn từ 3x3 đến 6x6. Đạt 3 sao khi số lượt '
            'không vượt mức tối ưu, 2 sao nếu hơn tối đa 3 lượt.',
      ),
    ],
    legend: [
      LegendItem(_icon(Icons.lightbulb, Colors.amber), 'Đèn đang sáng'),
      LegendItem(_icon(Icons.lightbulb_outline), 'Đèn đã tắt'),
      LegendItem(_icon(Icons.undo), 'Hoàn tác / Làm lại'),
      LegendItem(_icon(Icons.tips_and_updates_outlined), 'Gợi ý ô nên bấm'),
    ],
    tip:
        'Giải từng hàng từ trên xuống: tắt hết đèn hàng trên bằng cách bấm '
        'ô ở hàng dưới.',
  ),
  'sliding': GameTutorial(
    steps: const [
      TutorialStep(
        Icons.open_with,
        'Trượt ô',
        'Chạm một ô cạnh chỗ trống để trượt nó vào đó. Chạm ô ở xa thì cả '
            'hàng hoặc cột trượt theo. Cũng có thể vuốt theo hướng muốn trượt.',
      ),
      TutorialStep(
        Icons.format_list_numbered,
        'Mục tiêu',
        'Xếp các số từ nhỏ đến lớn, ô trống nằm ở góc dưới bên phải. Ở chế '
            'độ Ảnh, hãy ghép lại bức tranh.',
      ),
      TutorialStep(
        Icons.visibility_outlined,
        'Công cụ hỗ trợ',
        'Giữ nút mắt để xem ảnh gốc. Có hoàn tác, tạm dừng và 3 gợi ý mỗi '
            'ván; kỷ lục tính riêng cho từng kích thước.',
      ),
    ],
    legend: [
      LegendItem(_tile(Candy.blue), 'Ô số có thể trượt'),
      LegendItem(_icon(Icons.visibility_outlined), 'Giữ để xem ảnh gốc'),
      LegendItem(_icon(Icons.undo), 'Hoàn tác'),
      LegendItem(_icon(Icons.pause_circle_outline), 'Tạm dừng'),
    ],
    tip: 'Xếp xong hàng trên cùng và cột trái trước, rồi mới xử lý phần còn lại.',
  ),
  'kakuro': GameTutorial(
    steps: const [
      TutorialStep(
        Icons.calculate_outlined,
        'Đọc ô gợi ý',
        'Ô tối có đường chéo là ô gợi ý: số ở góc trên-phải là tổng các ô '
            'trắng liền bên phải; số ở góc dưới-trái là tổng các ô trắng '
            'liền bên dưới.',
      ),
      TutorialStep(
        Icons.dialpad,
        'Điền số',
        'Điền chữ số 1-9 vào ô trắng. Trong mỗi đoạn, các số không được '
            'trùng nhau và phải cộng đúng tổng.',
      ),
      TutorialStep(
        Icons.check_circle_outline,
        'Màu báo hiệu',
        'Đoạn đúng được tô xanh, ô lỗi tô đỏ. Có ghi chú bút chì, hoàn tác '
            'và vài lượt gợi ý.',
      ),
    ],
    legend: [
      LegendItem(
        _tile(const [Color(0xFF37474F), Color(0xFF263238)]),
        'Ô tối: chứa số gợi ý tổng',
      ),
      LegendItem(_tile(_cream), 'Ô trắng: điền số 1-9'),
      LegendItem(
        _icon(Icons.check_circle, Colors.greenAccent),
        'Đoạn đúng (tô xanh)',
      ),
      LegendItem(_icon(Icons.error, Colors.redAccent), 'Ô lỗi (tô đỏ)'),
      LegendItem(_icon(Icons.edit_note), 'Ghi chú bút chì'),
    ],
    tip:
        'Tổng 3 chỉ có thể là 1+2, tổng 4 trong 2 ô là 1+3: dùng các tổng '
        'đặc biệt này để mở đầu.',
  ),
};
