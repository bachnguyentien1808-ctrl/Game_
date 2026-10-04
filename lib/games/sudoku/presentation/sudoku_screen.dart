import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';

class _SudokuState {
  const _SudokuState(this.puzzle, this.solution, this.grid, this.selected);
  final Grid puzzle;
  final Grid solution;
  final Grid grid;
  final (int, int)? selected;

  bool isGiven(int r, int c) => puzzle[r][c] != 0;
  bool get solved {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (grid[r][c] != solution[r][c]) return false;
      }
    }
    return true;
  }
}

class _SudokuNotifier extends Notifier<_SudokuState> {
  @override
  _SudokuState build() => _fresh();

  _SudokuState _fresh() {
    final g = SudokuEngine.generate();
    return _SudokuState(
      g.puzzle,
      g.solution,
      SudokuEngine.copy(g.puzzle),
      null,
    );
  }

  void newGame() => state = _fresh();

  void select(int r, int c) =>
      state = _SudokuState(state.puzzle, state.solution, state.grid, (r, c));

  void put(int v) {
    final s = state.selected;
    if (s == null || state.isGiven(s.$1, s.$2)) return;
    final g = SudokuEngine.copy(state.grid)..[s.$1][s.$2] = v;
    state = _SudokuState(state.puzzle, state.solution, g, s);
  }
}

final _sudokuProvider = NotifierProvider<_SudokuNotifier, _SudokuState>(
  _SudokuNotifier.new,
);

class SudokuScreen extends ConsumerWidget {
  const SudokuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(_sudokuProvider);
    final n = ref.read(_sudokuProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(s.solved ? 'Sudoku - Hoàn thành!' : 'Sudoku'),
        actions: [
          IconButton(
            tooltip: 'Ván mới',
            icon: const Icon(Icons.refresh),
            onPressed: n.newGame,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 9,
                        ),
                    itemCount: 81,
                    itemBuilder: (_, i) {
                      final r = i ~/ 9;
                      final c = i % 9;
                      final v = s.grid[r][c];
                      final sel = s.selected == (r, c);
                      final wrong = v != 0 && v != s.solution[r][c];
                      return GestureDetector(
                        onTap: () => n.select(r, c),
                        child: Container(
                          decoration: BoxDecoration(
                            color: sel
                                ? scheme.primaryContainer
                                : scheme.surface,
                            border: Border(
                              top: _b(r % 3 == 0, scheme),
                              left: _b(c % 3 == 0, scheme),
                              right: _b(c == 8, scheme),
                              bottom: _b(r == 8, scheme),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            v == 0 ? '' : '$v',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: s.isGiven(r, c)
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: wrong ? scheme.error : scheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var v = 1; v <= 9; v++)
                      FilledButton.tonal(
                        onPressed: () => n.put(v),
                        child: Text('$v'),
                      ),
                    OutlinedButton(
                      onPressed: () => n.put(0),
                      child: const Icon(Icons.backspace_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BorderSide _b(bool thick, ColorScheme s) => BorderSide(
    width: thick ? 2 : 0.5,
    color: thick ? s.onSurface : s.outlineVariant,
  );
}
