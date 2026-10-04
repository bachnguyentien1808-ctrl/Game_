import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/lights_out/domain/lights_out_engine.dart';

const _id = 'lights_out';

class LightsOutScreen extends ConsumerStatefulWidget {
  const LightsOutScreen({super.key});

  @override
  ConsumerState<LightsOutScreen> createState() => _LightsOutScreenState();
}

class _LightsOutScreenState extends ConsumerState<LightsOutScreen> {
  late final ProgressStore _store = ref.read(progressStoreProvider);
  late LightsOut _game;

  @override
  void initState() {
    super.initState();
    final saved = _store.loadState(_id);
    LightsOut? restored;
    if (saved != null) {
      try {
        restored = LightsOut.fromJson(saved);
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
    _game = LightsOut.generate();
    _store
      ..recordStart(_id)
      ..saveState(_id, _game.toJson());
  }

  void _press(int r, int c) {
    if (_game.solved) return;
    setState(() => _game.press(r, c));
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
        title: Text(_game.solved ? 'Tắt đèn - Thắng!' : 'Tắt đèn'),
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
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var r = 0; r < _game.size; r++)
                        for (var c = 0; c < _game.size; c++)
                          GestureDetector(
                            onTap: () => _press(r, c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: _game.cells[r][c]
                                    ? s.tertiary
                                    : s.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _game.cells[r][c]
                                  ? Icon(Icons.lightbulb, color: s.onTertiary)
                                  : null,
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Tắt hết đèn. Bấm một ô sẽ đảo ô đó và 4 ô kề bên'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
