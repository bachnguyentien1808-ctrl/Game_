import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/minesweeper/domain/minesweeper_engine.dart';

const _id = 'minesweeper';

class MinesweeperScreen extends ConsumerStatefulWidget {
  const MinesweeperScreen({super.key});

  @override
  ConsumerState<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class _MinesweeperScreenState extends ConsumerState<MinesweeperScreen> {
  late final ProgressStore _store = ref.read(progressStoreProvider);
  late Minesweeper _game;
  int _seconds = 0;
  bool _flagMode = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final saved = _store.loadState(_id);
    Minesweeper? restored;
    if (saved != null) {
      try {
        restored = Minesweeper.fromJson(saved);
        _seconds = saved['seconds'] as int? ?? 0;
      } on Object {
        restored = null;
      }
    }
    if (restored != null && !restored.over) {
      _game = restored;
    } else {
      _fresh();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_game.placed || _game.over) return;
      setState(() => _seconds++);
      if (_seconds % 5 == 0) _save();
    });
  }

  void _fresh() {
    _game = Minesweeper();
    _seconds = 0;
    _store.recordStart(_id);
    _save();
  }

  void _save() =>
      _store.saveState(_id, {..._game.toJson(), 'seconds': _seconds});

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tap(int r, int c, {required bool flag}) {
    final wasOver = _game.over;
    setState(() {
      if (flag) {
        _game.toggleFlag(r, c);
      } else {
        _game.open(r, c);
      }
    });
    if (wasOver || !_game.over) {
      _save();
      return;
    }
    if (_game.won) _store.recordWin(_id, score: _seconds, lowerIsBetter: true);
    _store.clearState(_id);
  }

  Color _numColor(int n, ColorScheme s) => switch (n) {
    1 => Colors.blue,
    2 => Colors.green,
    3 => Colors.red,
    4 => Colors.indigo,
    _ => s.error,
  };

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final best = _store.stats(_id).best;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(
          _game.won
              ? 'Dò mìn - Thắng!'
              : _game.lost
              ? 'Dò mìn - Nổ mìn'
              : 'Dò mìn',
        ),
        actions: [
          IconButton(
            tooltip: 'Ván mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_fresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🚩 ${_game.flagsLeft}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '⏱ $_seconds s${best == null ? '' : '  ·  Kỷ lục: $best s'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: _game.cols / _game.rows,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _game.cols,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: _game.rows * _game.cols,
                    itemBuilder: (_, i) {
                      final r = i ~/ _game.cols;
                      final c = i % _game.cols;
                      final cell = _game.cells[r][c];
                      final showMine = _game.lost && cell.mine;
                      final shown = cell.open || showMine;
                      return GestureDetector(
                        onTap: () => _tap(r, c, flag: _flagMode),
                        onLongPress: () => _tap(r, c, flag: true),
                        onSecondaryTap: () => _tap(r, c, flag: true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: showMine
                                ? s.errorContainer
                                : shown
                                ? s.surfaceContainerHighest
                                : s.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: showMine
                              ? const Icon(Icons.brightness_7, size: 20)
                              : cell.flag
                              ? Icon(Icons.flag, size: 20, color: s.error)
                              : shown && cell.near > 0
                              ? Text(
                                  '${cell.near}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: _numColor(cell.near, s),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.touch_app),
                      label: Text('Mở ô'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.flag),
                      label: Text('Cắm cờ'),
                    ),
                  ],
                  selected: {_flagMode},
                  onSelectionChanged: (v) =>
                      setState(() => _flagMode = v.first),
                ),
                const SizedBox(height: 8),
                const Text('Nhấn giữ hoặc chuột phải cũng cắm cờ được'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
