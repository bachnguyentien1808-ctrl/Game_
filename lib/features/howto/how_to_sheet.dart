import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/ui/game_logo.dart';
import 'package:puzzle_hub/games/game_registry.dart';

/// Noi dung huong dan: GameInfo.howTo, chua co thi dung subtitle.
String howToText(GameInfo g) {
  final t = g.howTo?.trim();
  if (t != null && t.isNotEmpty) return t;
  return 'Mục tiêu: ${g.subtitle}.\n'
      'Ván đang chơi được lưu tự động, thoát ra rồi vào lại vẫn chơi tiếp được.';
}

Future<void> showHowTo(BuildContext context, GameInfo g) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => HowToSheet(game: g),
  );
}

class HowToSheet extends StatelessWidget {
  const HowToSheet({required this.game, super.key});

  final GameInfo game;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final lines = howToText(game)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GameLogo(id: game.id, size: 52),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cách chơi', style: t.labelLarge),
                        Text(game.title, style: t.headlineSmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (final (i, l) in lines.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        child: Text('${i + 1}', style: t.labelSmall),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l, style: t.bodyLarge)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.pop(context);
                    router.go('/play/${game.id}');
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Chơi ngay'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
