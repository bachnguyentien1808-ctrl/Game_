import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/games/nonogram/domain/nonogram_engine.dart';

class NonogramScreen extends StatefulWidget {
  const NonogramScreen({super.key});

  @override
  State<NonogramScreen> createState() => _NonogramScreenState();
}

class _NonogramScreenState extends State<NonogramScreen> {
  int _level = 0;
  late NonogramPuzzle _puzzle;
  late List<List<int>> _grid;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  void _load(int level) {
    _level = level;
    _puzzle = NonogramPuzzle(nonogramPuzzles[level].rows);
    _grid = List.generate(_puzzle.size, (_) => List.filled(_puzzle.size, 0));
  }

  void _tap(int r, int c, {required bool mark}) {
    setState(() {
      final cur = _grid[r][c];
      final target = mark ? 2 : 1;
      _grid[r][c] = cur == target ? 0 : target;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final n = _puzzle.size;
    final solved = _puzzle.isSolved(_grid);
    final rowClues = _puzzle.rowClues;
    final colClues = _puzzle.colClues;
    final maxRow = rowClues.fold<int>(1, (m, e) => e.length > m ? e.length : m);
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
            onPressed: () => setState(() => _load(_level)),
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
                    ButtonSegment(value: i, label: Text('Màn ${i + 1}')),
                ],
                selected: {_level},
                onSelectionChanged: (v) => setState(() => _load(v.first)),
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
              SizedBox(height: maxRow > 0 ? 16 : 0),
              const Text('Chạm: tô ô · Nhấn giữ hoặc chuột phải: đánh dấu X'),
            ],
          ),
        ),
      ),
    );
  }
}
