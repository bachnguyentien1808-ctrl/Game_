import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/ui/fx.dart';

/// Nhom game de loc o man chinh.
enum GameCategory {
  all('Tất cả', Icons.apps_rounded),
  number('Số', Icons.pin_outlined),
  logic('Logic', Icons.psychology_outlined),
  memory('Trí nhớ', Icons.style_outlined);

  GameCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Phan nhom theo id game; game moi chua co trong bang mac dinh Logic.
const _categoryOf = <String, GameCategory>{
  'sudoku': GameCategory.number,
  '2048': GameCategory.number,
  'kakuro': GameCategory.number,
  'sliding': GameCategory.number,
  'nonogram': GameCategory.logic,
  'minesweeper': GameCategory.logic,
  'lights_out': GameCategory.logic,
  'memory': GameCategory.memory,
};

GameCategory categoryOf(String id) => _categoryOf[id] ?? GameCategory.logic;

bool animationsOff(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Hop icon tron goc mau nhat, dung cho the game va hero.
class IconTile extends StatelessWidget {
  const IconTile({
    required this.icon,
    this.size = 44,
    this.background,
    this.foreground,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? s.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.56,
        color: foreground ?? s.onPrimaryContainer,
      ),
    );
  }
}

/// Lop bam co hieu ung lun nhe + rung + am tap.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.borderRadius = 20,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final off = animationsOff(context);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _down && !off ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTapDown: (_) => _set(true),
            onTapUp: (_) => _set(false),
            onTapCancel: () => _set(false),
            onTap: widget.onTap == null
                ? null
                : () {
                    GameFx.tap();
                    Sfx.play(SfxKind.tap);
                    widget.onTap!();
                  },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Xuat hien lan luot: truot len + hien dan theo [animation] da cat Interval.
class StaggerIn extends StatelessWidget {
  const StaggerIn({required this.animation, required this.child, super.key});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (_, child) {
      final v = animation.value;
      return Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 24),
          child: child,
        ),
      );
    },
    child: child,
  );
}

/// Khung gioi han be rong noi dung tren man lon.
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, this.maxWidth = 720, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
