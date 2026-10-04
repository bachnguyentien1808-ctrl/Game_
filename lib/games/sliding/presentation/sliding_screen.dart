import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/sliding/domain/sliding_engine.dart';

const _id = 'sliding';

class SlidingScreen extends ConsumerStatefulWidget {
  const SlidingScreen({super.key});

  @override
  ConsumerState<SlidingScreen> createState() => _SlidingScreenState();
}

class _SlidingScreenState extends ConsumerState<SlidingScreen> {
  late final ProgressStore _store = ref.read(progressStoreProvider);
  late SlidingPuzzle _game;

  @override
  void initState() {
    super.initState();
    final saved = _store.loadState(_id);
    SlidingPuzzle? restored;
    if (saved != null) {
      try {
        restored = SlidingPuzzle.fromJson(saved);
      } on Object {
        restored = null;
      }
    }
    if (restored != null && !restored.solved) {
      _game = restored;
    } else {
      _fresh();
    }
  }

  void _fresh() {
    _game = SlidingPuzzle.generate();
    _store
      ..recordStart(_id)
      ..saveState(_id, _game.toJson());
  }

  void _tap(int i) {
    if (_game.solved) return;
    var moved = false;
    setState(() => moved = _game.tap(i));
    if (!moved) return;
    if (_game.solved) {
      _store
        ..recordWin(_id, score: _game.moves, lowerIsBetter: true)
        ..clearState(_id);
    } else {
      _store.saveState(_id, _game.toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final best = _store.stats(_id).best;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Text(_game.solved ? 'Xếp số - Thắng!' : 'Xếp số'),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Số lượt: ${_game.moves}${best == null ? '' : '  ·  Kỷ lục: $best'}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 1,
                  child: GridView.count(
                    crossAxisCount: _game.size,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < _game.tiles.length; i++)
                        _game.tiles[i] == 0
                            ? const SizedBox.shrink()
                            : GestureDetector(
                                onTap: () => _tap(i),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _game.tiles[i] == i + 1
                                        ? s.tertiaryContainer
                                        : s.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${_game.tiles[i]}',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: s.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Xếp số từ 1 đến 15, ô trống ở góc dưới phải'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
