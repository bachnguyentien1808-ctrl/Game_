import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/theme/day_phase.dart';
import 'package:puzzle_hub/core/ui/glass.dart';

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

/// Bat/tat nen chuyen dong (test tat de pumpAndSettle khong bi treo).
abstract final class CandyMotion {
  static bool animatedBackground = true;
}

/// Danh dau "man nay da co nen rieng" de CandyBackground long ben trong
/// (nhieu man game tu boc) khong ve de len nen cua game.
class GameBackdropScope extends InheritedWidget {
  const GameBackdropScope({required super.child, super.key});

  static bool isActive(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GameBackdropScope>() != null;

  @override
  bool updateShouldNotify(GameBackdropScope oldWidget) => false;
}

/// Chon file anh nen theo buoi, chi dung anh do nguoi dung cung cap.
/// Man hinh chinh: bg_sky (ngay), bg_sky_dusk, bg_sky_night.
/// Cac game: bg_game (ngay); chieu va dem dung chung anh chieu/dem cua man
/// hinh chinh vi cung mot kieu canh dao bay.
abstract final class BackdropAssets {
  static const _dir = 'assets/images/';

  static String resolve(String dayAsset, DayPhase phase) {
    if (phase == DayPhase.day) return dayAsset;
    final base = dayAsset.replaceFirst(_dir, '').replaceFirst('.webp', '');
    final scene = base == 'bg_game' ? 'bg_sky' : base;
    return '$_dir$scene${phase.suffix}.webp';
  }
}

/// Buoi hien tai cua nen (ngay / chieu / toi), do app cung cap theo cai dat.
class BackdropPhaseScope extends InheritedWidget {
  const BackdropPhaseScope({
    required this.phase,
    required super.child,
    super.key,
  });

  final DayPhase phase;

  static DayPhase? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackdropPhaseScope>()?.phase;

  @override
  bool updateShouldNotify(BackdropPhaseScope old) => old.phase != phase;
}

/// Nen anh troi cham tran + troi nhe (zoom va truot cham, khong gian roi).
class AnimatedBackdrop extends StatefulWidget {
  const AnimatedBackdrop({
    required this.asset,
    required this.child,
    this.light = false,
    this.animate = true,
    super.key,
  });

  final String asset;
  final bool light;
  final Widget child;

  /// false: anh dung yen, khong hieu ung (dung trong man choi game).
  final bool animate;

  @override
  State<AnimatedBackdrop> createState() => _AnimatedBackdropState();
}

class _AnimatedBackdropState extends State<AnimatedBackdrop>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  /// Troi cua may/chim/hat sang: mot vong 45 giay (so nguyen lan tren
  /// moi vat nen vong lap khong giat).
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 45),
  );

  /// Nhip hieu ung nho (sao nhap nhay, dom dom, sao bang), lap moi 14 giay.
  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        !widget.animate ||
        !CandyMotion.animatedBackground ||
        MediaQuery.disableAnimationsOf(context);
    if (still) {
      _c
        ..stop()
        ..value = .5;
      _fx
        ..stop()
        ..value = 0;
      _drift
        ..stop()
        ..value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
      _fx.repeat();
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _fx.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Khong co BackdropPhaseScope (vd. trong test): theo do sang cua theme.
    final phase =
        BackdropPhaseScope.maybeOf(context) ??
        (widget.light ? DayPhase.day : DayPhase.night);
    final light = phase == DayPhase.day;
    final path = BackdropAssets.resolve(widget.asset, phase);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: light
                  ? const [Color(0xFFBFE6FF), Color(0xFFFFF0D2)]
                  : const [Candy.bgTop, Candy.bgBottom],
            ),
          ),
        ),
        ClipRect(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, child) {
                if (!widget.animate) return child!;
                final t = Curves.easeInOut.transform(_c.value);
                // Phu kin man hinh (BoxFit.cover); phong 4-8% va troi ngang nhe
                // trong phan du ra, nen khong bao gio lo mep anh.
                return Transform.scale(
                  scale: 1.06 + .05 * t,
                  child: FractionalTranslation(
                    translation: Offset((t - .5) * .04, (.5 - t) * .018),
                    child: child,
                  ),
                );
              },
              // Doi buoi thi mo dan sang anh moi (khong giat).
              child: ColorFiltered(
                colorFilter: _lift(phase),
                child: AnimatedSwitcher(
                  duration: CandyMotion.animatedBackground
                      ? const Duration(milliseconds: 1400)
                      : Duration.zero,
                  // Phu kin toan bo khung (mac dinh Stack chi giu kich thuoc anh).
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, ?current],
                  ),
                  child: Image.asset(
                    path,
                    key: ValueKey(path),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Hieu ung dong theo buoi: ngay (may, chim, phan hoa), chieu (may vang,
        // chim, tan lua), dem (sao, dom dom, sao bang).
        if (widget.animate && CandyMotion.animatedBackground)
          IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_fx, _drift]),
                builder: (_, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _SkyFxPainter(phase, _fx.value, _drift.value),
                ),
              ),
            ),
          ),
        // Lop phu: toi hon o theme toi, nhe o theme sang.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: light
                  ? const [Color(0x00FFFFFF), Color(0x00FFFFFF)]
                  : const [Color(0x00000000), Color(0x00000000)],
            ),
          ),
        ),
        // Giao dien cung doi mau theo buoi: ngay giu nguyen, chieu am, dem lanh.
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: _tintFor(phase)),
          duration: CandyMotion.animatedBackground
              ? const Duration(milliseconds: 1400)
              : Duration.zero,
          builder: (_, tint, child) => ColorFiltered(
            colorFilter: ColorFilter.mode(
              tint ?? Colors.white,
              BlendMode.modulate,
            ),
            child: child,
          ),
          child: widget.child,
        ),
      ],
    );
  }

  /// Nang do anh nen (dem sang hon nhieu, chieu hoi sang) cho de nhin; ban
  /// ngay giu nguyen.
  static ColorFilter _lift(DayPhase p) {
    final (k, off) = switch (p) {
      DayPhase.day => (1.0, 0.0),
      DayPhase.dusk => (1.1, 5.0),
      DayPhase.night => (1.4, 18.0),
    };
    return ColorFilter.matrix([
      k, 0, 0, 0, off, //
      0, k, 0, 0, off,
      0, 0, k, 0, off,
      0, 0, 0, 1, 0,
    ]);
  }

  static Color _tintFor(DayPhase p) => switch (p) {
    DayPhase.day => const Color(0xFFFFFFFF),
    DayPhase.dusk => const Color(0xFFFFF6EC),
    DayPhase.night => const Color(0xFFF6F8FF),
  };
}

/// Hieu ung ve len anh nen theo buoi. [t] la nhip nhanh 0..1 (8 giay), [d] la
/// troi cham 0..1 (45 giay, vat di chuyen nhan so nguyen lan de lap lien mach).
class _SkyFxPainter extends CustomPainter {
  _SkyFxPainter(this.phase, this.t, this.d);

  final DayPhase phase;
  final double t;
  final double d;

  static final _rng = math.Random(11);
  static final _stars = List.generate(
    90,
    (_) => (
      x: _rng.nextDouble(),
      y: _rng.nextDouble() * .5,
      r: .6 + _rng.nextDouble() * 1.3,
      ph: _rng.nextDouble(),
      sp: 1 + _rng.nextInt(3),
    ),
  );
  static final _flies = List.generate(
    16,
    (_) => (
      x: _rng.nextDouble(),
      y: .55 + _rng.nextDouble() * .4,
      ax: .01 + _rng.nextDouble() * .03,
      ay: .01 + _rng.nextDouble() * .02,
      ph: _rng.nextDouble(),
      r: 1.6 + _rng.nextDouble() * 1.6,
    ),
  );
  static final _clouds = List.generate(
    7,
    (_) => (
      x: _rng.nextDouble(),
      y: .05 + _rng.nextDouble() * .4,
      s: .7 + _rng.nextDouble() * .9,
      m: 1 + _rng.nextInt(3),
      a: .38 + _rng.nextDouble() * .3,
    ),
  );
  static final _birds = List.generate(
    3,
    (i) => (
      x: _rng.nextDouble(),
      y: .1 + .09 * i + _rng.nextDouble() * .04,
      m: 3 + i,
      size: 7.0 + i * 2,
      ph: _rng.nextDouble(),
    ),
  );
  static final _motes = List.generate(
    30,
    (_) => (
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      r: 1.2 + _rng.nextDouble() * 1.8,
      ph: _rng.nextDouble(),
      m: 2 + _rng.nextInt(3),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (phase == DayPhase.night) {
      _night(canvas, size);
    } else {
      _clouds_(canvas, size);
      _birds_(canvas, size);
      _motes_(canvas, size);
    }
  }

  void _clouds_(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = phase == DayPhase.day ? Colors.white : const Color(0xFFFFC79A);
    const puffs = [
      (-1.6, .2, .8),
      (-.7, -.2, 1.0),
      (.3, -.35, 1.2),
      (1.2, -.1, .95),
      (2.0, .2, .7),
    ];
    for (final c in _clouds) {
      final px = ((c.x + d * c.m) % 1.0) * (w * 1.5) - w * .25;
      final r = h * .034 * c.s;
      final paint = Paint()
        ..color = base.withValues(alpha: c.a * .6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .55);
      for (final p in puffs) {
        canvas.drawCircle(
          Offset(px + p.$1 * r, c.y * h + p.$2 * r),
          r * p.$3,
          paint,
        );
      }
    }
  }

  void _birds_(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final color = phase == DayPhase.day
        ? const Color(0xFF2B3A55)
        : const Color(0xFF3A1F2E);
    final paint = Paint()
      ..color = color.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final b in _birds) {
      for (var k = 0; k < 3; k++) {
        final bx = ((b.x + d * b.m) % 1.0) * (w * 1.2) - w * .1 - k * 22;
        final by =
            b.y * h +
            math.sin(2 * math.pi * (d * b.m * 2 + b.ph)) * 6 +
            (k.isOdd ? 9 : 0) * (k == 1 ? 1 : -1);
        final flap = math.sin(2 * math.pi * (t * 8 + b.ph + k * .2));
        final sp = b.size;
        final path = Path()
          ..moveTo(bx - sp, by - flap * sp * .7)
          ..quadraticBezierTo(bx - sp * .45, by + sp * .15, bx, by)
          ..quadraticBezierTo(
            bx + sp * .45,
            by + sp * .15,
            bx + sp,
            by - flap * sp * .7,
          );
        canvas.drawPath(path, paint);
      }
    }
  }

  void _motes_(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final color = phase == DayPhase.day
        ? const Color(0xFFFFFBD0)
        : const Color(0xFFFFA94D);
    for (final m in _motes) {
      final y = 1 - ((m.y + d * m.m) % 1.0);
      final x = m.x + .02 * math.sin(2 * math.pi * (t * 2 + m.ph));
      final k = .5 + .5 * math.sin(2 * math.pi * (t * 3 + m.ph));
      final p = Offset(x * w, y * h);
      canvas
        ..drawCircle(
          p,
          m.r * 3.2,
          Paint()..color = color.withValues(alpha: .16 * (.4 + k)),
        )
        ..drawCircle(
          p,
          m.r,
          Paint()..color = color.withValues(alpha: .35 + .5 * k),
        );
    }
  }

  void _night(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (final s in _stars) {
      final k = .5 + .5 * math.sin(2 * math.pi * (t * s.sp + s.ph));
      final a = (.15 + .75 * k * k).clamp(0.0, 1.0);
      final p = Offset(s.x * w, s.y * h);
      canvas
        ..drawCircle(
          p,
          s.r * 2.6,
          Paint()..color = const Color(0xFFBFD4FF).withValues(alpha: a * .22),
        )
        ..drawCircle(
          p,
          s.r,
          Paint()..color = Colors.white.withValues(alpha: a),
        );
    }
    for (final f in _flies) {
      final ang = 2 * math.pi * (t + f.ph);
      final p = Offset(
        (f.x + f.ax * math.sin(ang)) * w,
        (f.y + f.ay * math.cos(ang * 2)) * h,
      );
      final blink = .55 + .45 * math.sin(ang * 3);
      canvas
        ..drawCircle(
          p,
          f.r * 4,
          Paint()
            ..color = const Color(0xFFFFE066).withValues(alpha: .18 * blink),
        )
        ..drawCircle(
          p,
          f.r,
          Paint()
            ..color = const Color(0xFFFFF3B0).withValues(alpha: .9 * blink),
        );
    }
    // Sao bang: xuat hien trong 8% dau cua moi nhip.
    if (t < .08) {
      final k = t / .08;
      final from = Offset(w * .25, h * .08);
      final to = Offset(w * .6, h * .3);
      final head = Offset.lerp(from, to, k)!;
      final tail = Offset.lerp(from, to, (k - .25).clamp(0.0, 1.0))!;
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 1 - k * .6),
            ],
          ).createShader(Rect.fromPoints(tail, head))
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SkyFxPainter old) =>
      old.t != t || old.d != d || old.phase != phase;
}

/// Nen toan man hinh (anh troi, chuyen dong). Neu da nam trong nen rieng cua
/// mot game thi chi tra ve [child].
class CandyBackground extends StatelessWidget {
  const CandyBackground({required this.child, this.light = false, super.key});

  final Widget child;

  /// Bien the cho theme sang (lop phu nhe hon).
  final bool light;

  static const asset = 'assets/images/bg_sky.webp';

  @override
  Widget build(BuildContext context) {
    if (GameBackdropScope.isActive(context)) return child;
    return AnimatedBackdrop(asset: asset, light: light, child: child);
  }
}

/// Nen cua cac man game: mot anh chung, dung yen, doi theo buoi.
class GameBackdrop extends StatelessWidget {
  const GameBackdrop({required this.gameId, required this.child, super.key});

  final String gameId;
  final Widget child;

  /// Moi game dung chung mot anh nen (xem [BackdropAssets]).
  static String assetFor(String gameId) => 'assets/images/bg_game.webp';

  @override
  Widget build(BuildContext context) {
    return GameBackdropScope(
      child: AnimatedBackdrop(
        animate: false,
        asset: assetFor(gameId),
        light: Theme.of(context).brightness == Brightness.light,
        child: child,
      ),
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
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.dim
        ? [
            Color.alphaBlend(Colors.black45, widget.colors.first),
            Color.alphaBlend(Colors.black45, widget.colors.last),
          ]
        : widget.colors;
    final r = widget.circle ? 999.0 : widget.radius;
    return MouseRegion(
      cursor: widget.onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down
              ? 0.95
              : _hover
              ? 1.08
              : 1,
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
              // Chu trong nut luon nam giua, ke ca khi nut gian het chieu ngang.
              alignment: Alignment.center,
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
    final g = GlassStyle.of(context);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerLeft,
      children: [
        Container(
          margin: const EdgeInsets.only(left: 16),
          padding: const EdgeInsets.fromLTRB(26, 5, 14, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: g.pill,
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              color: g.pillText,
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
            border: Border.all(color: Colors.white, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x44000000), offset: Offset(0, 2)),
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
    // Khung kinh mo: vien trang trong suot + nen xanh dam, doi theo buoi.
    final g = GlassStyle.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: g.outerBorder, width: 2),
            color: g.outer,
            boxShadow: [
              const BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 8),
                blurRadius: 14,
              ),
              BoxShadow(
                color: g.outerBorder.withValues(alpha: .3),
                blurRadius: 24,
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: g.inner,
            ),
            child: Padding(padding: const EdgeInsets.all(4), child: child),
          ),
        ),
      ),
    );
  }
}
