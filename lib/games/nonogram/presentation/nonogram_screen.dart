import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/nonogram/domain/nonogram_engine.dart';

const _id = 'nonogram';

class NonogramScreen extends ConsumerStatefulWidget {
  const NonogramScreen({super.key});

  @override
  ConsumerState<NonogramScreen> createState() => _NonogramScreenState();
}

class _NonogramScreenState extends ConsumerState<NonogramScreen> {
  late final ProgressStore _store = ref.read(progressStoreProvider);
  int _level = 0;
  late NonogramPuzzle _puzzle;

  /// Luoi dang choi cua tung man (giu lai khi doi man).
  late List<List<List<int>>> _grids;

  /// Cac man da giai.
  final Set<int> _done = {};

  List<List<int>> get _grid => _grids[_level];

  static List<List<int>> _blank(int n) =>
      List.generate(n, (_) => List.filled(n, 0));

  @override
  void initState() {
    super.initState();
    _grids = [
      for (final p in nonogramPuzzles) _blank(NonogramPuzzle(p.rows).size),
    ];
    final saved = _store.loadState(_id);
    if (saved != null) {
      try {
        final gs = saved['grids'] as List;
        for (var i = 0; i < _grids.length && i < gs.length; i++) {
          final g = decodeIntGrid(gs[i]);
          if (g.length == _grids[i].length) _grids[i] = g;
        }
        _done.addAll((saved['done'] as List).cast<int>());
        _level = (saved['level'] as int).clamp(0, nonogramPuzzles.length - 1);
      } on Object {
        // trang thai hong -> bo qua
      }
    }
    _puzzle = NonogramPuzzle(nonogramPuzzles[_level].rows);
  }

  void _save() => _store.saveState(_id, {
    'level': _level,
    'grids': _grids,
    'done': _done.toList(),
  });

  void _select(int level) {
    setState(() {
      _level = level;
      _puzzle = NonogramPuzzle(nonogramPuzzles[level].rows);
    });
    _save();
  }

  void _reset() {
    setState(() => _grids[_level] = _blank(_puzzle.size));
    _done.remove(_level);
    _save();
  }

  void _tap(int r, int c, {required bool mark}) {
    final fresh = _grid.every((row) => row.every((v) => v == 0));
    setState(() {
      final cur = _grid[r][c];
      final target = mark ? 2 : 1;
      _grid[r][c] = cur == target ? 0 : target;
    });
    if (fresh) _store.recordStart(_id);
    if (_puzzle.isSolved(_grid) && _done.add(_level)) {
      _store.recordWin(_id);
    }
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final n = _puzzle.size;
    final solved = _puzzle.isSolved(_grid);
    final rowClues = _puzzle.rowClues;
    final colClues = _puzzle.colClues;
    final maxCol = colClues.fold<int>(1, (m, e) => e.length > m ? e.length : m);
    const cell = 34.0;

    Widget clueBox(List<int> clue, {required bool vertical}) => Container(
      width: vertical ? cell : null,
      height: vertical ? null : cell,
      alignment: vertical ? Alignment.bottomCenter : Alignment.centerRight,
      padding: const EdgeInsets.all(2),
      child: vertical
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [for (final v in clue) Text('$v')],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final v in clue)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('$v'),
                  ),
              ],
            ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(solved ? 'Nonogram - Hoàn thành!' : 'Nonogram'),
        actions: [
          IconButton(
            tooltip: 'Làm lại',
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < nonogramPuzzles.length; i++)
                    ButtonSegment(
                      value: i,
                      label: Text('Màn ${i + 1}'),
                      icon: _done.contains(i) ? const Icon(Icons.check) : null,
                    ),
                ],
                selected: {_level},
                onSelectionChanged: (v) => _select(v.first),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      SizedBox(height: maxCol * 20.0 + 8),
                      for (final c in rowClues) clueBox(c, vertical: false),
                    ],
                  ),
                  Column(
                    children: [
                      SizedBox(
                        height: maxCol * 20.0 + 8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final c in colClues)
                              clueBox(c, vertical: true),
                          ],
                        ),
                      ),
                      for (var r = 0; r < n; r++)
                        Row(
                          children: [
                            for (var c = 0; c < n; c++)
                              GestureDetector(
                                onTap: () => _tap(r, c, mark: false),
                                onLongPress: () => _tap(r, c, mark: true),
                                onSecondaryTap: () => _tap(r, c, mark: true),
                                child: Container(
                                  width: cell,
                                  height: cell,
                                  decoration: BoxDecoration(
                                    color: _grid[r][c] == 1
                                        ? s.primary
                                        : s.surface,
                                    border: Border.all(color: s.outlineVariant),
                                  ),
                                  child: _grid[r][c] == 2
                                      ? Icon(
                                          Icons.close,
                                          size: 18,
                                          color: s.outline,
                                        )
                                      : null,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Chạm: tô ô · Nhấn giữ hoặc chuột phải: đánh dấu X'),
            ],
          ),
        ),
      ),
    );
  }
}
