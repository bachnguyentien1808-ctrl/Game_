import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/games/game2048/domain/game2048_engine.dart';

class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key});

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen> {
  final _rng = Random();
  final _focus = FocusNode();
  late Board2048 _board = Board2048.start(rng: _rng);
  int _best = 0;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _move(Dir d) {
    setState(() {
      if (_board.move(d)) {
        _board.spawn(_rng);
        _best = max(_best, _board.score);
      }
    });
  }

  void _restart() => setState(() => _board = Board2048.start(rng: _rng));

  static final Map<LogicalKeyboardKey, Dir> _keys = {
    LogicalKeyboardKey.arrowLeft: Dir.left,
    LogicalKeyboardKey.arrowRight: Dir.right,
    LogicalKeyboardKey.arrowUp: Dir.up,
    LogicalKeyboardKey.arrowDown: Dir.down,
  };

  Color _tile(int v, ColorScheme s) {
    if (v == 0) return s.surfaceContainerHighest;
    final t = (log(v) / ln2 / 11).clamp(0.0, 1.0);
    return Color.lerp(s.primaryContainer, s.primary, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final over = !_board.canMove;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('2048'),
        actions: [
          IconButton(
            tooltip: 'Ván mới',
            icon: const Icon(Icons.refresh),
            onPressed: _restart,
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (e) {
          final d = _keys[e.logicalKey];
          if (e is KeyDownEvent && d != null) _move(d);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanEnd: (details) {
            final v = details.velocity.pixelsPerSecond;
            if (v.distance < 200) return;
            _move(
              v.dx.abs() > v.dy.abs()
                  ? (v.dx > 0 ? Dir.right : Dir.left)
                  : (v.dy > 0 ? Dir.down : Dir.up),
            );
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Điểm: ${_board.score}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('Cao nhất: $_best'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        children: [
                          GridView.count(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (final row in _board.cells)
                                for (final v in row)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: _tile(v, s),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      v == 0 ? '' : '$v',
                                      style: TextStyle(
                                        fontSize: v >= 1024 ? 22 : 28,
                                        fontWeight: FontWeight.w700,
                                        color: v >= 8
                                            ? s.onPrimary
                                            : s.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                          if (over)
                            Container(
                              decoration: BoxDecoration(
                                color: s.surface.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: FilledButton(
                                onPressed: _restart,
                                child: const Text('Hết nước đi - Chơi lại'),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Vuốt hoặc dùng phím mũi tên để gộp ô'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
