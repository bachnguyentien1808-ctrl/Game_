import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/glass.dart';

/// O diem gon dat trong AppBar cua moi game: luon thay tong diem khi choi.
/// Diem dem tang dan khi duoc cong, kem "+N" bay len mot nhip.
class ScoreChip extends StatelessWidget {
  const ScoreChip({super.key});

  @override
  Widget build(BuildContext context) {
    // Man choi dung rieng le (vd. trong test) khong co kho diem: an o diem.
    ProgressStore store;
    try {
      store = ProviderScope.containerOf(context).read(progressStoreProvider);
    } on Object {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<int>(
      valueListenable: store.version,
      builder: (_, _, _) => _ScoreView(points: store.totalPoints),
    );
  }
}

class _ScoreView extends StatefulWidget {
  const _ScoreView({required this.points});

  final int points;

  @override
  State<_ScoreView> createState() => _ScoreViewState();
}

class _ScoreViewState extends State<_ScoreView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late int _from = widget.points;
  int _delta = 0;

  @override
  void didUpdateWidget(_ScoreView old) {
    super.didUpdateWidget(old);
    if (widget.points > old.points) {
      _from = old.points;
      _delta = widget.points - old.points;
      if (!MediaQuery.disableAnimationsOf(context)) {
        _pop.forward(from: 0);
      }
    } else {
      _from = widget.points;
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Tooltip(
      message: 'Tổng điểm',
      child: Semantics(
        label: 'Tổng điểm ${widget.points}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pop,
                builder: (_, child) => Transform.scale(
                  scale: 1 + .18 * (1 - (2 * _pop.value - 1).abs()),
                  child: child,
                ),
                child: Builder(
                  builder: (context) {
                    final g = GlassStyle.of(context);
                    return Container(
                      key: const Key('score-chip'),
                      padding: const EdgeInsets.fromLTRB(5, 4, 12, 4),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Dong xu vang.
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE59A00),
                                width: 2,
                              ),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFFE066), Color(0xFFFFB300)],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          TweenAnimationBuilder<int>(
                            key: ValueKey(widget.points),
                            tween: IntTween(begin: _from, end: widget.points),
                            duration: reduce
                                ? Duration.zero
                                : const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => Text(
                              Scoring.format(v),
                              style: TextStyle(
                                color: g.pillText,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_delta > 0 && !reduce)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pop,
                      builder: (_, _) {
                        final k = _pop.value;
                        if (k <= 0 || k >= 1) return const SizedBox.shrink();
                        return Opacity(
                          opacity: (1 - k).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 6 + 26 * k),
                            child: Text(
                              '+${Scoring.format(_delta)}',
                              style: const TextStyle(
                                color: Color(0xFFFFEB3B),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                shadows: [
                                  Shadow(
                                    color: Color(0xCC000000),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
