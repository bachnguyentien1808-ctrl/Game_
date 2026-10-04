import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';

const _id = 'sudoku';

/// Do kho = so o bo trong.
const _levels = <String, int>{'Dễ': 36, 'Vừa': 46, 'Khó': 53};

class _SudokuState {
  const _SudokuState({
    required this.puzzle,
    required this.solution,
    required this.grid,
    required this.holes,
    this.selected,
  });

  factory _SudokuState.fromJson(Map<String, dynamic> j) => _SudokuState(
    puzzle: decodeIntGrid(j['p']),
    solution: decodeIntGrid(j['s']),
    grid: decodeIntGrid(j['g']),
    holes: j['h'] as int,
  );

  final Grid puzzle;
  final Grid solution;
  final Grid grid;
  final int holes;
  final (int, int)? selected;

  Map<String, dynamic> toJson() => {
    'p': puzzle,
    's': solution,
    'g': grid,
    'h': holes,
  };

  _SudokuState copyWith({Grid? grid, (int, int)? selected}) => _SudokuState(
    puzzle: puzzle,
    solution: solution,
    grid: grid ?? this.grid,
    holes: holes,
    selected: selected ?? this.selected,
  );

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
  ProgressStore get _store => ref.read(progressStoreProvider);

  @override
  _SudokuState build() {
    final saved = _store.loadState(_id);
    if (saved != null) {
      try {
        return _SudokuState.fromJson(saved);
      } on Object {
        // trang thai hong -> bat dau van moi
      }
    }
    return _fresh(_levels['Vừa']!);
  }

  _SudokuState _fresh(int holes) {
    final g = SudokuEngine.generate(holes: holes);
    final s = _SudokuState(
      puzzle: g.puzzle,
      solution: g.solution,
      grid: SudokuEngine.copy(g.puzzle),
      holes: holes,
    );
    _store
      ..recordStart(_id)
      ..saveState(_id, s.toJson());
    return s;
  }

  void newGame(int holes) => state = _fresh(holes);

  void select(int r, int c) => state = state.copyWith(selected: (r, c));

  void _commit(_SudokuState next) {
    final wasSolved = state.solved;
    state = next;
    if (next.solved && !wasSolved) {
      _store
        ..recordWin(_id)
        ..clearState(_id);
    } else {
      _store.saveState(_id, next.toJson());
    }
  }

  void put(int v) {
    final s = state.selected;
    if (s == null || state.isGiven(s.$1, s.$2) || state.solved) return;
    _commit(
      state.copyWith(grid: SudokuEngine.copy(state.grid)..[s.$1][s.$2] = v),
    );
  }

  /// Dien dung o dang chon.
  void hint() {
    final s = state.selected;
    if (s == null || state.isGiven(s.$1, s.$2) || state.solved) return;
    put(state.solution[s.$1][s.$2]);
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
    final sel = s.selected;
    final selVal = sel == null ? 0 : s.grid[sel.$1][sel.$2];
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(s.solved ? 'Sudoku - Hoàn thành!' : 'Sudoku'),
        actions: [
          IconButton(
            tooltip: 'Gợi ý (điền ô đang chọn)',
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: n.hint,
          ),
          PopupMenuButton<int>(
            tooltip: 'Ván mới',
            icon: const Icon(Icons.refresh),
            onSelected: n.newGame,
            itemBuilder: (_) => [
              for (final e in _levels.entries)
                PopupMenuItem(
                  value: e.value,
                  child: Text('Ván mới - ${e.key}'),
                ),
            ],
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
                      final isSel = sel == (r, c);
                      final sameNum = v != 0 && v == selVal && !isSel;
                      final wrong = v != 0 && v != s.solution[r][c];
                      return GestureDetector(
                        onTap: () => n.select(r, c),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSel
                                ? scheme.primaryContainer
                                : sameNum
                                ? scheme.secondaryContainer
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
                  runSpacing: 8,
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
