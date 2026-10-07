import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/glass.dart';
import 'package:puzzle_hub/core/ui/score_chip.dart';
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';
import 'package:puzzle_hub/games/nonogram/domain/nonogram_engine.dart';
import 'package:puzzle_hub/games/nonogram/domain/nonogram_progress.dart';
import 'package:puzzle_hub/games/nonogram/presentation/nonogram_play.dart';
import 'package:puzzle_hub/games/nonogram/presentation/nonogram_thumb.dart';

const _id = 'nonogram';

class NonogramScreen extends ConsumerStatefulWidget {
  const NonogramScreen({super.key});

  @override
  ConsumerState<NonogramScreen> createState() => _NonogramScreenState();
}

class _NonogramScreenState extends ConsumerState<NonogramScreen> {
  late final GameStore _store = GameStore(ref.read(progressStoreProvider));
  late NonogramProgress _progress;

  /// Tranh dang choi; null = dang o man chon man.
  int? _current;
  NonogramGame? _game;
  int _seconds = 0;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _progress = NonogramProgress.fromJson(
      _store.loadState(_id),
      (i) => i >= 0 && i < nonogramPuzzles.length
          ? nonogramPuzzles[i].rows.length
          : null,
    );
  }

  void _persist() => _store.saveState(_id, _progress.toJson());

  void _open(int i) {
    final puzzle = NonogramPuzzle(nonogramPuzzles[i].rows);
    final save = _progress.saves[i];
    final game = NonogramGame(puzzle, grid: save?.grid);
    if (save != null) {
      game
        ..hintsUsed = save.hints
        ..mistakes = save.mistakes
        ..locked.addAll(save.locked);
    }
    setState(() {
      _current = i;
      _game = game;
      _seconds = save?.seconds ?? 0;
      _epoch++;
    });
  }

  void _save(int seconds) {
    final i = _current;
    final g = _game;
    if (i == null || g == null) return;
    if (g.isSolved && !g.isBlank) return; // da thang, tien do da ghi
    if (g.isBlank) {
      _progress.saves.remove(i);
    } else {
      _progress.saves[i] = LevelSave(
        grid: [for (final r in g.grid) List<int>.of(r)],
        seconds: seconds,
        hints: g.hintsUsed,
        mistakes: g.mistakes,
        locked: g.locked.toList(),
      );
    }
    _persist();
  }

  void _solved(int seconds, int stars) {
    final i = _current!;
    _progress.recordWin(i, seconds, stars);
    _persist();
    _store.recordWin(_id);
  }

  void _close() => setState(() {
    _current = null;
    _game = null;
  });

  @override
  Widget build(BuildContext context) {
    final i = _current;
    if (i != null && _game != null) {
      return NonogramPlay(
        key: ValueKey('$i-$_epoch'),
        index: i,
        game: _game!,
        initialSeconds: _seconds,
        onSave: _save,
        onFirstMove: () => _store.recordStart(_id),
        onSolved: _solved,
        onAward: (p) => _store.awardPoints(_id, p),
        onBack: _close,
      );
    }
    return _select(context);
  }

  Widget _select(BuildContext context) {
    final solved = _progress.best.length;
    final total = nonogramPuzzles.length;
    return CandyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          actions: const [
            ScoreChip(),
            HelpAction(gameId: 'nonogram'),
          ],
          leading: BackButton(onPressed: () => context.go(_store.homeRoute)),
          title: const Text('Nonogram'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                GlassPanel(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: GlassStat(
                          icon: Icons.emoji_events_outlined,
                          colors: Candy.orange,
                          text: 'Đã giải $solved/$total tranh',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CandyBar(value: solved / total, height: 12),
                    ],
                  ),
                ),
                for (final size in nonogramPackSizes) ..._pack(context, size),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _pack(BuildContext context, int size) {
    final indices = puzzleIndicesOfSize(size);
    final done = _progress.solvedIn(indices);
    final colors = Candy.palettes[size % Candy.palettes.length];
    return [
      const SizedBox(height: 18),
      GlassPanel(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Flexible(
                  child: CandyRibbon(text: 'Gói ${size}x$size', colors: colors),
                ),
                const Spacer(),
                GlassStat(
                  icon: Icons.check,
                  colors: Candy.green,
                  text: '$done/${indices.length}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth - 20) / 3;
                return Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [for (final i in indices) _card(context, i, w)],
                );
              },
            ),
          ],
        ),
      ),
    ];
  }

  Widget _card(BuildContext context, int i, double width) {
    final pic = nonogramPuzzles[i];
    final puzzle = NonogramPuzzle(pic.rows);
    final best = _progress.best[i];
    final save = _progress.saves[i];
    final colors = Candy.palettes[i % Candy.palettes.length];
    return SizedBox(
      width: width,
      child: _Press(
        onTap: () => _open(i),
        builder: ({required down}) => Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: GlassStyle.of(context).outerBorder,
              width: 2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: Candy.deep(colors),
                offset: Offset(0, down ? 1 : 4),
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
              const CandyGloss(radius: 14),
              Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: GlassStyle.of(context).inner,
                        border: Border.all(color: Colors.white54, width: 1.5),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: NonogramThumb(
                              solution: puzzle.solution,
                              top: Color(pic.top),
                              bottom: Color(pic.bottom),
                              grid: save?.grid,
                              colored: best != null,
                            ),
                          ),
                          if (best != null)
                            const Positioned(
                              right: -2,
                              bottom: -2,
                              child: _GoldCheck(),
                            )
                          else if (save == null)
                            const Positioned.fill(
                              child: Icon(
                                Icons.lock_open_outlined,
                                color: Colors.white54,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pic.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      shadows: [
                        Shadow(color: Color(0x88000000), blurRadius: 2),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var k = 0; k < 3; k++)
                        Icon(
                          k < (best?.stars ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          size: 18,
                          color: k < (best?.stars ?? 0)
                              ? const Color(0xFFFFE066)
                              : Colors.white70,
                          shadows: const [
                            Shadow(color: Color(0x66000000), blurRadius: 2),
                          ],
                        ),
                    ],
                  ),
                  Text(
                    best != null
                        ? formatSeconds(best.seconds)
                        : save != null
                        ? 'Đang chơi'
                        : ' ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      shadows: [
                        Shadow(color: Color(0x88000000), blurRadius: 2),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dau tich vang tren tranh da giai.
class _GoldCheck extends StatelessWidget {
  const _GoldCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE066), Color(0xFFE0A458)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 3)],
      ),
      child: const Icon(Icons.check, size: 16, color: Candy.brown),
    );
  }
}

/// Thanh tien do kieu keo: ray kem, ruot vang.
class _CandyBar extends StatelessWidget {
  const _CandyBar({required this.value, required this.height});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final g = GlassStyle.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        color: g.inner,
        border: Border.all(color: g.outerBorder, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE066), Color(0xFFF08A1C)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bam co nhun xuong (scale-down) khi cham.
class _Press extends StatefulWidget {
  const _Press({required this.onTap, required this.builder});

  final VoidCallback onTap;
  final Widget Function({required bool down}) builder;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.builder(down: _down),
      ),
    );
  }
}
