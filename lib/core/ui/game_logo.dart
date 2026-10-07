import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

/// Logo thuong hieu (anh): ban lon cho man chao, ban nho (nen ro net o kich
/// thuoc be) cho thanh tieu de. Tai anh loi thi dung logo manh ghep ve tay.
class BrandLogo extends StatelessWidget {
  const BrandLogo({this.height = 72, super.key});

  final double height;

  /// Duoi 90 px dung logo_small.webp (420 px), con lai logo.webp (1000 px).
  bool get small => height <= 90;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Puzzle Hub',
      image: true,
      child: Image.asset(
        small ? 'assets/images/logo_small.webp' : 'assets/images/logo.webp',
        key: const Key('app-logo'),
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => AppLogo(size: height * .7),
      ),
    );
  }
}

/// Logo app: manh ghep trang tren nen tim chang bong (giong icon cai dat).
class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 44, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return _Emblem(
      size: size,
      colors: const [Color(0xFF8C9EFF), Color(0xFF3D3FD0)],
      child: CustomPaint(
        size: Size.square(size),
        painter: const _PuzzlePainter(),
      ),
    );
  }
}

class _PuzzlePainter extends CustomPainter {
  const _PuzzlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Rect r(double l, double t, double r, double b) =>
        Rect.fromLTRB(l * s, t * s, r * s, b * s);
    Path circle(double cx, double cy, double rad) => Path()
      ..addOval(
        Rect.fromCircle(center: Offset(cx * s, cy * s), radius: rad * s),
      );
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(r(.22, .3, .7, .78), Radius.circular(.07 * s)),
      );
    var p = Path.combine(PathOperation.union, body, circle(.46, .25, .1));
    p = Path.combine(PathOperation.union, p, circle(.74, .535, .1));
    p = Path.combine(PathOperation.difference, p, circle(.22, .54, .085));
    p = Path.combine(PathOperation.difference, p, circle(.46, .78, .085));
    canvas
      ..drawShadow(p, const Color(0xFF1A1B6B), 3, true)
      ..drawPath(p, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PuzzlePainter old) => false;
}

/// Khung emblem bong dung chung cho logo app va logo tung game.
class _Emblem extends StatelessWidget {
  const _Emblem({
    required this.size,
    required this.colors,
    required this.child,
  });

  final double size;
  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * .28);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.white70, width: size * .045),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(color: Candy.deep(colors), offset: Offset(0, size * .06)),
          const BoxShadow(
            color: Color(0x44000000),
            offset: Offset(0, 4),
            blurRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CandyGloss(radius: size * .2, opacity: .38),
            child,
          ],
        ),
      ),
    );
  }
}

/// Logo rieng cua tung game, ve bang widget (khong can file anh).
class GameLogo extends StatelessWidget {
  const GameLogo({required this.id, this.size = 48, super.key});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _Emblem(
      size: size,
      colors: Candy.forId(id),
      child: Padding(
        padding: EdgeInsets.all(size * .16),
        child: FittedBox(child: SizedBox.square(dimension: 100, child: _art())),
      ),
    );
  }

  Widget _art() => switch (id) {
    'sudoku' => const _SudokuArt(),
    '2048' => const _TilesArt(),
    'nonogram' => const _NonogramArt(),
    'memory' => const _MemoryArt(),
    'minesweeper' => const _MineArt(),
    'lights_out' => const _BulbArt(),
    'sliding' => const _SlidingArt(),
    'kakuro' => const _KakuroArt(),
    _ => const Center(
      child: Icon(Icons.extension_rounded, color: Colors.white, size: 70),
    ),
  };
}

Widget _cell({Color color = Colors.white, Widget? child, double r = 8}) =>
    DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), offset: Offset(0, 2)),
        ],
      ),
      child: child == null ? null : Center(child: child),
    );

Text _digit(String t, double fs, [Color c = const Color(0xFF3B2A5C)]) => Text(
  t,
  style: TextStyle(
    color: c,
    fontSize: fs,
    fontWeight: FontWeight.w900,
    height: 1,
  ),
);

class _TilesArt extends StatelessWidget {
  const _TilesArt();

  @override
  Widget build(BuildContext context) {
    const tiles = [
      ('2', Color(0xFFFFF3C4)),
      ('4', Color(0xFFFFD580)),
      ('8', Color(0xFFFFAB60)),
      ('16', Color(0xFFFF7043)),
    ];
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      padding: const EdgeInsets.all(4),
      children: [
        for (final t in tiles)
          _cell(
            color: t.$2,
            r: 10,
            child: _digit(
              t.$1,
              t.$1.length > 1 ? 28 : 34,
              Colors.brown.shade800,
            ),
          ),
      ],
    );
  }
}

class _SudokuArt extends StatelessWidget {
  const _SudokuArt();

  @override
  Widget build(BuildContext context) {
    const digits = {0: '5', 4: '3', 8: '7', 2: '9', 6: '1'};
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      padding: const EdgeInsets.all(4),
      children: [
        for (var i = 0; i < 9; i++)
          _cell(
            color: digits.containsKey(i) ? Colors.white : Colors.white54,
            r: 6,
            child: digits[i] == null ? null : _digit(digits[i]!, 22),
          ),
      ],
    );
  }
}

class _NonogramArt extends StatelessWidget {
  const _NonogramArt();

  @override
  Widget build(BuildContext context) {
    const heart = [
      '.XX.XX.',
      'XXXXXXX',
      'XXXXXXX',
      '.XXXXX.',
      '..XXX..',
      '...X...',
    ];
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          for (final row in heart)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in row.split(''))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c == 'X' ? Colors.white : Colors.white24,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MemoryArt extends StatelessWidget {
  const _MemoryArt();

  @override
  Widget build(BuildContext context) {
    Widget card(Widget face, double angle, Color c) => Transform.rotate(
      angle: angle,
      child: SizedBox(
        width: 46,
        height: 62,
        child: _cell(color: c, r: 9, child: face),
      ),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 6,
          top: 20,
          child: card(
            const Icon(Icons.help_rounded, color: Color(0xFF7B3FE4), size: 34),
            -.22,
            Colors.white,
          ),
        ),
        Positioned(
          right: 6,
          top: 14,
          child: card(
            const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 38),
            .2,
            const Color(0xFFFFF3C4),
          ),
        ),
      ],
    );
  }
}

class _MineArt extends StatelessWidget {
  const _MineArt();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const Icon(Icons.brightness_7, color: Colors.white, size: 92),
      Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Color(0xFFD7263D),
          shape: BoxShape.circle,
        ),
      ),
      const Positioned(
        top: 2,
        right: 14,
        child: Icon(Icons.flag, color: Color(0xFFFFEB3B), size: 36),
      ),
    ],
  );
}

class _BulbArt extends StatelessWidget {
  const _BulbArt();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 78,
        height: 78,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0xAAFFEB3B), blurRadius: 24)],
        ),
      ),
      const Icon(Icons.lightbulb, color: Color(0xFFFFF176), size: 86),
    ],
  );
}

class _SlidingArt extends StatelessWidget {
  const _SlidingArt();

  @override
  Widget build(BuildContext context) {
    const v = ['1', '2', '3', ''];
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      padding: const EdgeInsets.all(4),
      children: [
        for (final t in v)
          t.isEmpty
              ? const SizedBox.shrink()
              : _cell(r: 10, child: _digit(t, 34)),
      ],
    );
  }
}

class _KakuroArt extends StatelessWidget {
  const _KakuroArt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: CustomPaint(
                      painter: _ClueCellPainter(),
                      child: const Stack(
                        children: [
                          Positioned(top: 4, right: 6, child: _Tiny('7')),
                          Positioned(bottom: 4, left: 6, child: _Tiny('12')),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _cell(child: _digit('4', 30)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _cell(child: _digit('3', 30)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _cell(child: _digit('8', 30)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tiny extends StatelessWidget {
  const _Tiny(this.t);

  final String t;

  @override
  Widget build(BuildContext context) => Text(
    t,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w900,
      height: 1,
    ),
  );
}

class _ClueCellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas
      ..drawRRect(rr, Paint()..color = const Color(0xFF263238))
      ..drawLine(
        Offset.zero,
        Offset(size.width, size.height),
        Paint()
          ..color = Colors.white54
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_ClueCellPainter old) => false;
}
