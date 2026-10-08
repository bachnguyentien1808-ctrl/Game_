import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/theme/day_phase.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

/// Bang mau "kinh mo" cua giao dien game, doi theo buoi (ngay / chieu / dem)
/// va theo che do Sang / Toi / Tu dong cua app.
class GlassStyle {
  const GlassStyle({
    required this.outer,
    required this.outerBorder,
    required this.inner,
    required this.pill,
    required this.pillText,
    required this.panel,
  });

  /// Vien kinh quanh ban choi.
  final Color outer;
  final Color outerBorder;

  /// Nen sau (xanh dam) cua ban choi.
  final Color inner;

  /// Vien thuoc (thoi gian, loi, diem) va mau chu tren do.
  final Color pill;
  final Color pillText;

  /// Bang kinh chua nut dieu khien.
  final Color panel;

  static const day = GlassStyle(
    outer: Color(0x66FFFFFF),
    outerBorder: Color(0xB3FFFFFF),
    inner: Color(0xF2163560),
    pill: Color(0xE6FFFFFF),
    pillText: Color(0xFF1B3A66),
    panel: Color(0x4DFFFFFF),
  );

  static const dusk = GlassStyle(
    outer: Color(0x80FFD9B8),
    outerBorder: Color(0xE6FFE6CC),
    inner: Color(0xF5361E46),
    pill: Color(0xF2FFEFE0),
    pillText: Color(0xFF5A2E3A),
    panel: Color(0xB32E1A3C),
  );

  static const night = GlassStyle(
    outer: Color(0x8CB8C8FF),
    outerBorder: Color(0xE6D0DCFF),
    inner: Color(0xF50C1946),
    pill: Color(0xF5EEF2FF),
    pillText: Color(0xFF1B2D5E),
    panel: Color(0xB30E1D4A),
  );

  static GlassStyle forPhase(DayPhase p) => switch (p) {
    DayPhase.day => day,
    DayPhase.dusk => dusk,
    DayPhase.night => night,
  };

  /// Theo buoi cua app; neu chua co (vd. test) thi theo do sang cua theme.
  static GlassStyle of(BuildContext context) {
    final p =
        BackdropPhaseScope.maybeOf(context) ??
        (Theme.of(context).brightness == Brightness.light
            ? DayPhase.day
            : DayPhase.night);
    return forPhase(p);
  }
}

/// Bang kinh mo (vien trang mo, nen trong, lam mo phia sau).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.radius = 26,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final g = GlassStyle.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: g.panel,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: g.outerBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: g.outerBorder.withValues(alpha: .28),
                blurRadius: 18,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Thanh tren cung dang vien thuoc kinh chua cac o thong so (gio, loi, tam
/// dung...), dan deu theo chieu ngang.
class GlassBar extends StatelessWidget {
  const GlassBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      ),
    );
  }
}

/// Vien thuoc trang: bieu tuong tron mau + chu (gio, loi, so luot...).
class GlassStat extends StatelessWidget {
  const GlassStat({
    required this.icon,
    required this.text,
    this.colors = Candy.blue,
    super.key,
  });

  final IconData icon;
  final String text;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final g = GlassStyle.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
      decoration: BoxDecoration(
        color: g.pill,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: g.pillText,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nut X tron o goc tren ben phai cua mot khoi kinh; di chuot vao thi do len.
class GlassCloseButton extends StatefulWidget {
  const GlassCloseButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  State<GlassCloseButton> createState() => _GlassCloseButtonState();
}

class _GlassCloseButtonState extends State<GlassCloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Đóng',
      child: Semantics(
        button: true,
        label: 'Đóng',
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            key: const Key('glass-close'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hover
                    ? const Color(0xFFE53935)
                    : Colors.white.withValues(alpha: .18),
                border: Border.all(
                  color: _hover
                      ? const Color(0xFFFFCDD2)
                      : Colors.white.withValues(alpha: .55),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
