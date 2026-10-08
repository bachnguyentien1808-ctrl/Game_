import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';
import 'package:puzzle_hub/features/settings/settings_screen.dart';
import 'package:puzzle_hub/features/stats/stats_screen.dart';
import 'package:puzzle_hub/games/game_registry.dart';
import 'package:puzzle_hub/games/memory/domain/memory_engine.dart';
import 'package:puzzle_hub/games/minesweeper/domain/minesweeper_engine.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';

const _ink = Color(0xFF1B2A4A);
const _accent = Color(0xFF3D5AFE);
const _amber = Color(0xFFF59E0B);

/// Hien mot bang tha xuong goc tren ben phai (duoi AppBar), nen mo dan.
Future<void> _showDropdown(
  BuildContext context, {
  required WidgetBuilder builder,
  double top = 56,
  double width = 320,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, top, 12, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Material(
              type: MaterialType.transparency,
              child: builder(ctx),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, a, _, child) {
      if (MediaQuery.disableAnimationsOf(ctx)) return child;
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween<double>(
            begin: .94,
            end: 1,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  );
}

/// Bang trang bo goc, bong mem: dung chung cho Thanh tich va Menu.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: dark ? const Color(0xFF1E2A44) : Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: dark ? Colors.white : _ink),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bang Thanh tich
// ---------------------------------------------------------------------------

/// Game dang mo (duong dan /play/ten-game), null neu khong o trong game.
String? _currentGameId(BuildContext context) {
  try {
    final path = GoRouter.of(context)
        .routeInformationProvider
        .value
        .uri
        .pathSegments;
    if (path.length >= 2 && path.first == 'play') return path[1];
  } on Object {
    return null;
  }
  return null;
}

/// Mo man Thong ke / Cai dat. Trong game thi hien de len man choi (van thay
/// game phia sau); o trang chu thi sang man rieng.
void _openPage(
  BuildContext context, {
  required bool overlay,
  required String route,
  required Widget page,
}) {
  if (!overlay) {
    context.push(route);
    return;
  }
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng',
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => page,
    transitionBuilder: (ctx, a, _, child) => MediaQuery.disableAnimationsOf(ctx)
        ? child
        : FadeTransition(opacity: a, child: child),
  );
}

/// Bang Thanh tich: tong diem, so van thang, ti le thang va ky luc.
/// Dang choi Sudoku thi ky luc chia theo muc do kho, con lai theo tung game.
Future<void> showAchievements(BuildContext context, {double top = 56}) {
  final ProgressStore store;
  try {
    store = ProviderScope.containerOf(context).read(progressStoreProvider);
  } on Object {
    return Future.value();
  }
  final gameId = _currentGameId(context);
  return _showDropdown(
    context,
    top: top,
    builder: (_) => _AchievementsCard(store: store, gameId: gameId),
  );
}

/// Bang Thanh tich gan co dinh tren man choi (khi man hinh du rong), tu cap
/// nhat theo diem va ky luc.
class AchievementsPanel extends StatelessWidget {
  const AchievementsPanel({this.gameId, super.key});

  final String? gameId;

  @override
  Widget build(BuildContext context) {
    final ProgressStore store;
    try {
      store = ProviderScope.containerOf(context).read(progressStoreProvider);
    } on Object {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<int>(
      valueListenable: store.version,
      builder: (_, _, _) => Material(
        type: MaterialType.transparency,
        child: _AchievementsCard(store: store, gameId: gameId),
      ),
    );
  }
}

String _clock(int sec) =>
    '${(sec ~/ 60).toString().padLeft(2, '0')}:'
    '${(sec % 60).toString().padLeft(2, '0')}';

String _bestText(GameInfo g, int? best) {
  if (best == null || g.bestKind == null) return '--';
  return switch (g.bestKind!) {
    BestKind.seconds => _clock(best),
    BestKind.moves => '$best lượt',
    BestKind.score => Scoring.format(best),
  };
}

String _lines(int? b) => b == null ? '--' : '$b lượt';

/// Ky luc cua mot game (theo muc do kho / kich thuoc neu co). Ngoai game
/// (trang chu) thi liet ke ky luc chung cua tung game.
List<(String, String)> _recordsFor(ProgressStore store, String? gameId) {
  String clock(String id) {
    final b = store.stats(id).best;
    return b == null ? '--:--' : _clock(b);
  }

  switch (gameId) {
    case 'sudoku':
      return [for (final l in SudokuLevel.values) (l.label, clock(l.statsId))];
    case 'minesweeper':
      return [
        for (final l in MineLevel.values)
          if (l != MineLevel.custom) (l.label, clock(l.statsId)),
      ];
    case 'memory':
      return [
        for (final z in MemorySize.values)
          (z.label, _lines(store.stats(z.statsId).best)),
      ];
    case 'sliding':
      return [
        for (final n in const [3, 4, 5])
          ('${n}x$n', _lines(store.stats('sliding.$n').best)),
      ];
    case 'kakuro':
      return [
        for (final (name, n) in const [('Dễ', 5), ('Vừa', 6), ('Khó', 7)])
          (name, clock('kakuro.n$n')),
      ];
    case '2048':
      final b = store.stats('2048').best;
      return [('Điểm cao nhất', b == null ? '--' : Scoring.format(b))];
    case 'lights_out':
      return [('Ít lượt nhất', _lines(store.stats('lights_out').best))];
    case 'nonogram':
      return [('Số tranh đã giải', '${store.stats('nonogram').won}')];
  }
  return [
    for (final g in gameRegistry)
      (g.title, _bestText(g, store.stats(g.id).best)),
  ];
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.store, required this.gameId});

  final ProgressStore store;
  final String? gameId;

  @override
  Widget build(BuildContext context) {
    var played = 0;
    var won = 0;
    for (final g in gameRegistry) {
      final s = store.stats(g.id);
      played += s.played;
      won += s.won;
    }
    final rate = played == 0 ? 0 : (won * 100 / played).round();
    final rows = [
      for (final (label, value) in _recordsFor(store, gameId))
        _Line(label, value),
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .75,
      ),
      child: _Card(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Title(Icons.emoji_events_outlined, 'Thành tích'),
              const SizedBox(height: 6),
              _Line('Tổng điểm', Scoring.format(store.totalPoints)),
              _Line('Đã hoàn thành', '$won'),
              _Line('Tỷ lệ đúng', '$rate%'),
              const Divider(height: 28),
              const _Title(Icons.workspace_premium_outlined, 'Kỷ lục'),
              const SizedBox(height: 6),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _amber, size: 28),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(
            value,
            style: const TextStyle(
              color: _accent,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nut + menu rang cua
// ---------------------------------------------------------------------------

/// Nut rang cua (tron, sang) trong AppBar cua man choi.
class HubMenuAction extends StatelessWidget {
  const HubMenuAction({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 8),
      child: Tooltip(
        message: 'Menu',
        child: Semantics(
          button: true,
          label: 'Menu',
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('hub-menu'),
            behavior: HitTestBehavior.opaque,
            onTap: () => showHubMenu(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xE6FFFFFF),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: _accent,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Menu cua nut rang cua: Trang chu (chi o man choi), Thong ke, Cai dat,
/// Huong dan. Che do sang/toi chi chinh trong Cai dat.
Future<void> showHubMenu(
  BuildContext context, {
  double top = 56,
  bool showHome = true,
}) {
  return _showDropdown(
    context,
    top: top,
    width: 260,
    builder: (ctx) {
      return _Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHome)
              _MenuRow(
                icon: Icons.home_rounded,
                color: const Color(0xFFFF8A00),
                label: 'Trang chủ',
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go('/');
                },
              ),
            _MenuRow(
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF22A06B),
              label: 'Thống kê',
              onTap: () {
                Navigator.of(ctx).pop();
                _openPage(
                  context,
                  overlay: showHome,
                  route: '/stats',
                  page: const StatsScreen(),
                );
              },
            ),
            _MenuRow(
              icon: Icons.tune_rounded,
              color: _accent,
              label: 'Cài đặt',
              onTap: () {
                Navigator.of(ctx).pop();
                _openPage(
                  context,
                  overlay: showHome,
                  route: '/settings',
                  page: const SettingsScreen(),
                );
              },
            ),
            _MenuRow(
              icon: Icons.help_outline_rounded,
              color: const Color(0xFFE91E8C),
              label: 'Hướng dẫn',
              onTap: () {
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                // Trong game: huong dan thang game do; o trang chu: chon game.
                final id = _currentGameId(context);
                if (id != null) {
                  showTutorial(context, id);
                } else {
                  _showGuidePicker(context, top: top);
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showGuidePicker(BuildContext context, {required double top}) {
  return _showDropdown(
    context,
    top: top,
    width: 280,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * .72,
      ),
      child: _Card(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: _Title(Icons.help_outline_rounded, 'Hướng dẫn'),
              ),
              const SizedBox(height: 6),
              for (final g in gameRegistry)
                _MenuRow(
                  icon: g.icon,
                  color: _accent,
                  label: g.title,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (context.mounted) showTutorial(context, g.id);
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
