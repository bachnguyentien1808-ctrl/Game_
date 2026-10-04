import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/games/game_registry.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(progressStoreProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzle Hub'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn',
            onSelected: (_) => _confirmReset(context, store),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('Xóa toàn bộ tiến độ')),
            ],
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: store.version,
        builder: (context, _, _) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: gameRegistry.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) =>
              _GameCard(game: gameRegistry[i], store: store),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, ProgressStore store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa toàn bộ tiến độ?'),
        content: const Text('Thống kê, kỷ lục và các ván đang chơi dở sẽ mất.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok ?? false) await store.resetAll();
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.store});

  final GameInfo game;
  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final stats = store.stats(game.id);
    final scheme = Theme.of(context).colorScheme;
    final resume = store.hasState(game.id);
    final best = game.bestLabel(stats.best);
    final line = [
      if (stats.played > 0) 'Đã chơi ${stats.played}',
      if (stats.won > 0) 'Thắng ${stats.won}',
      ?best,
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: Icon(game.icon, size: 36),
        title: Row(
          children: [
            Flexible(child: Text(game.title)),
            if (resume) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text('Chơi tiếp'),
                visualDensity: VisualDensity.compact,
                backgroundColor: scheme.tertiaryContainer,
                side: BorderSide.none,
              ),
            ],
          ],
        ),
        subtitle: Text(
          line.isEmpty ? game.subtitle : '${game.subtitle}\n$line',
        ),
        isThreeLine: line.isNotEmpty,
        onTap: () => context.go('/play/${game.id}'),
      ),
    );
  }
}
