import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _Header('Giao diện', Icons.palette_rounded),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
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
                          label: Text('Tự động'),
                        ),
                      ],
                      selected: {s.themeMode},
                      onSelectionChanged: (v) {
                        GameFx.tap();
                        c.setThemeMode(v.first);
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      'Sáng: ban ngày · Tối: ban đêm · Tự động: đổi theo '
                      'giờ thật (sáng, chiều, tối)',
                      style: TextStyle(color: _inkSoft, fontSize: 12),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
                    child: Text(
                      'Màu chủ đạo',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Wrap(
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
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _Header('Phản hồi', Icons.notifications_active_rounded),
            _Panel(
              child: Column(
                children: [
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
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _Header('Dữ liệu', Icons.storage_rounded),
            _Panel(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.slideshow_outlined),
                    title: const Text('Xem lại giới thiệu'),
                    onTap: () async {
                      await c.resetOnboarding();
                      if (context.mounted) context.go('/');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: _danger),
                    title: const Text(
                      'Xóa toàn bộ tiến độ',
                      style: TextStyle(
                        color: _danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: const Text(
                      'Thống kê, kỷ lục, chuỗi ngày, ván dở',
                    ),
                    onTap: () =>
                        confirmReset(context, ref.read(progressStoreProvider)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _Header('Giới thiệu', Icons.info_rounded),
            _Panel(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Puzzle Hub'),
                subtitle: Text(
                  'Phiên bản $appVersion · ${gameRegistry.length} trò chơi',
                ),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Puzzle Hub',
                  applicationVersion: appVersion,
                  applicationIcon: const IconTile(
                    icon: Icons.extension_rounded,
                  ),
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

const _ink = Candy.brown;
const _inkSoft = Color(0xFF9A6B3C);
const _danger = Color(0xFFC62828);

/// Nhan muc dang vien thuoc kem, doc duoc tren moi nen.
class _Header extends StatelessWidget {
  const _Header(this.text, this.icon);

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 16, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Candy.gold, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Candy.cream, Candy.creamDeep],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                offset: Offset(0, 3),
                blurRadius: 3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: _ink),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khung kem chua cac dieu khien Material; ep mau nau de doc o ca theme toi.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final themed = base.copyWith(
      listTileTheme: const ListTileThemeData(
        textColor: _ink,
        iconColor: _ink,
        titleTextStyle: TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
        subtitleTextStyle: TextStyle(color: _inkSoft, fontSize: 13),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? Colors.white : Candy.gold,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected)
              ? Candy.green.last
              : Candy.creamDeep,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Candy.gold),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(_ink),
          iconColor: const WidgetStatePropertyAll(_ink),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Candy.gold, width: 2),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected)
                ? Candy.orange.first
                : Colors.transparent,
          ),
        ),
      ),
    );
    return CandyFrame(
      padding: 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFFFF6E3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Theme(
            data: themed,
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
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
    final light = Color.lerp(color, Colors.white, 0.45)!;
    final deep = Color.alphaBlend(Colors.black38, color);
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
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [light, color],
              ),
              border: Border.all(
                color: selected ? _ink : Candy.gold,
                width: selected ? 3.5 : 2,
              ),
              boxShadow: [BoxShadow(color: deep, offset: const Offset(0, 3))],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      key: ValueKey(1),
                      shadows: [
                        Shadow(color: Color(0x88000000), blurRadius: 2),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
