import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/features/common/shell_widgets.dart';
import 'package:puzzle_hub/games/game_registry.dart';

const appVersion = '1.0.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Cài đặt'),
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _Header('Giao diện'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Sáng'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Tối'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Hệ thống'),
                  ),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) {
                  GameFx.tap();
                  c.setThemeMode(v.first);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Màu chủ đạo',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                children: [
                  for (final (i, (name, color)) in seedColors.indexed)
                    _SeedDot(
                      color: color,
                      name: name,
                      selected: i == s.seedIndex,
                      onTap: () {
                        GameFx.tap();
                        c.setSeed(i);
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 32),
            const _Header('Phản hồi'),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('Âm thanh'),
              value: s.sound,
              onChanged: (v) async {
                await c.setSound(on: v);
                if (v) Sfx.play(SfxKind.success);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration),
              title: const Text('Rung'),
              value: s.haptics,
              onChanged: (v) async {
                await c.setHaptics(on: v);
                GameFx.success();
              },
            ),
            const Divider(height: 32),
            const _Header('Dữ liệu'),
            ListTile(
              leading: const Icon(Icons.slideshow_outlined),
              title: const Text('Xem lại giới thiệu'),
              onTap: () async {
                await c.resetOnboarding();
                if (context.mounted) context.go('/');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text(
                'Xóa toàn bộ tiến độ',
                style: TextStyle(color: scheme.error),
              ),
              subtitle: const Text('Thống kê, kỷ lục, chuỗi ngày, ván dở'),
              onTap: () =>
                  confirmReset(context, ref.read(progressStoreProvider)),
            ),
            const Divider(height: 32),
            const _Header('Giới thiệu'),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Puzzle Hub'),
              subtitle: Text(
                'Phiên bản $appVersion · ${gameRegistry.length} trò chơi',
              ),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Puzzle Hub',
                applicationVersion: appVersion,
                applicationIcon: const IconTile(icon: Icons.extension_rounded),
                applicationLegalese: '© 2026 ALODEV',
                children: const [
                  SizedBox(height: 12),
                  Text(
                    'Tuyển tập trò chơi trí tuệ chơi ngoại tuyến. '
                    'Không quảng cáo, không thu thập dữ liệu.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> confirmReset(BuildContext context, ProgressStore store) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: const Text('Xóa toàn bộ tiến độ?'),
      content: const Text(
        'Thống kê, kỷ lục, chuỗi ngày và các ván đang chơi dở sẽ mất, không khôi phục được.',
      ),
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
  if (ok ?? false) {
    await store.resetAll();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa toàn bộ tiến độ')));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _SeedDot extends StatelessWidget {
  const _SeedDot({
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Màu $name',
      child: Tooltip(
        message: name,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(6),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? on : Colors.transparent,
                width: 3,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      key: ValueKey(1),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
