import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
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
        onBack: _close,
      );
    }
    return _select(context);
  }

  Widget _select(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final solved = _progress.best.length;
    final total = nonogramPuzzles.length;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(_store.homeRoute)),
        title: const Text('Nonogram'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events_outlined, color: s.primary),
                  const SizedBox(width: 8),
                  Text('Đã giải $solved/$total tranh', style: t.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: solved / total,
                  minHeight: 8,
                ),
              ),
              for (final size in nonogramPackSizes) ..._pack(context, size),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _pack(BuildContext context, int size) {
    final t = Theme.of(context).textTheme;
    final indices = puzzleIndicesOfSize(size);
    final done = _progress.solvedIn(indices);
    return [
      const SizedBox(height: 20),
      Row(
        children: [
          Text('Gói ${size}x$size', style: t.titleLarge),
          const Spacer(),
          Text('$done/${indices.length}', style: t.titleSmall),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: done / indices.length,
          minHeight: 4,
        ),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, box) {
          final w = (box.maxWidth - 20) / 3;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final i in indices) _card(context, i, w)],
          );
        },
      ),
    ];
  }

  Widget _card(BuildContext context, int i, double width) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final pic = nonogramPuzzles[i];
    final puzzle = NonogramPuzzle(pic.rows);
    final best = _progress.best[i];
    final save = _progress.saves[i];
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        color: s.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(i),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
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
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(
                            Icons.check_circle,
                            color: s.primary,
                            size: 20,
                          ),
                        )
                      else if (save == null)
                        Positioned.fill(
                          child: Icon(
                            Icons.lock_open_outlined,
                            color: s.outline.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pic.name,
                  style: t.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var k = 0; k < 3; k++)
                      Icon(
                        k < (best?.stars ?? 0) ? Icons.star : Icons.star_border,
                        size: 16,
                        color: k < (best?.stars ?? 0)
                            ? Colors.amber
                            : s.outline,
                      ),
                  ],
                ),
                Text(
                  best != null
                      ? formatSeconds(best.seconds)
                      : save != null
                      ? 'Đang chơi'
                      : ' ',
                  style: t.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
