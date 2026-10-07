import 'package:flutter/material.dart';

/// Bo dung cu giao dien kieu game casual: nut bong 3D, khung kem, thanh tai
/// nguyen, ruy bang. Mau co dinh, khong phu thuoc sang/toi cua theme.
class Candy {
  const Candy._();

  static const cream = Color(0xFFFFE9C4);
  static const creamDeep = Color(0xFFF2CF9B);
  static const gold = Color(0xFFE0A458);
  static const brown = Color(0xFF7A4A21);
  static const bgTop = Color(0xFF1B3A5C);
  static const bgBottom = Color(0xFF2F6F80);

  static const blue = [Color(0xFF5CC8FF), Color(0xFF1E7BE0)];
  static const green = [Color(0xFFA5E05B), Color(0xFF3FA535)];
  static const orange = [Color(0xFFFFC857), Color(0xFFF08A1C)];
  static const red = [Color(0xFFFF7A6B), Color(0xFFD7263D)];
  static const purple = [Color(0xFFC08BFF), Color(0xFF7B3FE4)];

  static const teal = [Color(0xFF5EEAD4), Color(0xFF0F9D8F)];
  static const pink = [Color(0xFFFF8FC8), Color(0xFFD6247E)];
  static const indigo = [Color(0xFF8C9EFF), Color(0xFF3949D8)];

  /// Bo mau xoay vong, moi game mot cap rieng (on dinh theo id).
  static const palettes = [
    blue,
    orange,
    green,
    purple,
    pink,
    teal,
    red,
    indigo,
  ];

  static List<Color> forId(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palettes[h % palettes.length];
  }

  /// Mau dam hon cua cap gradient, dung lam "day" cho hieu ung noi 3D.
  static Color deep(List<Color> g) => Color.alphaBlend(Colors.black38, g.last);
}

/// Nen gradient xanh dam toan man hinh.
class CandyBackground extends StatelessWidget {
  const CandyBackground({required this.child, this.light = false, super.key});

  final Widget child;

  /// Bien the nen sang (troi xanh nhat -> kem) cho theme sang.
  final bool light;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: light
              ? const [Color(0xFFBFE6FF), Color(0xFFFFF0D2)]
              : const [Candy.bgTop, Candy.bgBottom],
        ),
      ),
      child: child,
    );
  }
}

/// Lop bong trang o nua tren mot khoi mau.
class CandyGloss extends StatelessWidget {
  const CandyGloss({this.radius = 10, this.opacity = 0.34, super.key});

  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 2, 3, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: 0.45,
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: opacity),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nut bong 3D: gradient, vien kem-vang, vet bong, bong do duoi, nhun khi nhan.
class CandyButton extends StatefulWidget {
  const CandyButton({
    required this.child,
    required this.onPressed,
    this.colors = Candy.blue,
    this.radius = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.dim = false,
    this.circle = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final double radius;
  final EdgeInsets padding;

  /// Lam mo mau (nut chua chon).
  final bool dim;
  final bool circle;

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.dim
        ? [
            Color.alphaBlend(Colors.black45, widget.colors.first),
            Color.alphaBlend(Colors.black45, widget.colors.last),
          ]
        : widget.colors;
    final r = widget.circle ? 999.0 : widget.radius;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: Candy.gold, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: Candy.deep(colors),
                offset: Offset(0, _down ? 1 : 4),
              ),
              const BoxShadow(
                color: Color(0x55000000),
                offset: Offset(0, 7),
                blurRadius: 6,
              ),
            ],
          ),
          child: Stack(
            children: [
              CandyGloss(radius: r),
              Padding(
                padding: widget.padding,
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Color(0x88000000), blurRadius: 2),
                      ],
                    ),
                    child: IconTheme.merge(
                      data: const IconThemeData(color: Colors.white),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh tai nguyen: o tron mau chua bieu tuong + thanh kem chua so.
class CandyPill extends StatelessWidget {
  const CandyPill({
    required this.icon,
    required this.text,
    required this.colors,
    super.key,
  });

  final IconData icon;
  final String text;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerLeft,
      children: [
        Container(
          margin: const EdgeInsets.only(left: 16),
          padding: const EdgeInsets.fromLTRB(26, 5, 14, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Candy.gold, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Candy.cream, Candy.creamDeep],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                offset: Offset(0, 3),
                blurRadius: 3,
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Candy.brown,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Candy.gold, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), offset: Offset(0, 2)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}

/// Ruy bang xanh co hai duoi xe chu V, chua mot dong chu.
class CandyRibbon extends StatelessWidget {
  const CandyRibbon({required this.text, this.colors = Candy.blue, super.key});

  final String text;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: CustomPaint(painter: _RibbonPainter(colors))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 7),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              shadows: [Shadow(color: Color(0x99000000), blurRadius: 2)],
            ),
          ),
        ),
      ],
    );
  }
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const notch = 12.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - notch, h / 2)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(notch, h / 2)
      ..close();
    canvas
      ..drawShadow(path, Colors.black, 3, true)
      ..drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.5),
      );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.colors != colors;
}

/// Khung kem bo tron bao quanh vung choi.
class CandyFrame extends StatelessWidget {
  const CandyFrame({required this.child, this.padding = 8, super.key});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Candy.gold, width: 3),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Candy.cream, Candy.creamDeep],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFFB07A3E), offset: Offset(0, 5)),
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 9),
            blurRadius: 8,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF173B52),
        ),
        child: Padding(padding: const EdgeInsets.all(4), child: child),
      ),
    );
  }
}
