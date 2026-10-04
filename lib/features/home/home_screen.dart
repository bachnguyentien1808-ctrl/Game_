import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/games/game_registry.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle Hub')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: gameRegistry.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final g = gameRegistry[i];
          return Card(
            child: ListTile(
              leading: Icon(g.icon, size: 36),
              title: Text(g.title),
              subtitle: Text(g.subtitle),
              onTap: () => context.go('/play/${g.id}'),
            ),
          );
        },
      ),
    );
  }
}
