import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';

/// mm:ss (hoac h:mm:ss).
String formatClock(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

IconData levelIcon(SudokuLevel l) => switch (l) {
  SudokuLevel.easy => Icons.signal_cellular_alt_1_bar,
  SudokuLevel.medium => Icons.signal_cellular_alt_2_bar,
  SudokuLevel.hard => Icons.signal_cellular_alt,
  SudokuLevel.expert => Icons.local_fire_department_outlined,
};

/// Hang nut thao tac: hoan tac, lam lai, xoa, ghi chu, goi y.
class SudokuActions extends StatelessWidget {
  const SudokuActions({
    required this.canUndo,
    required this.canRedo,
    required this.notesOn,
    required this.hintsLeft,
    required this.onUndo,
    required this.onRedo,
    required this.onErase,
    required this.onNotes,
    required this.onHint,
    super.key,
  });

  final bool canUndo;
  final bool canRedo;
  final bool notesOn;
  final int hintsLeft;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onErase;
  final VoidCallback onNotes;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Row(
      children: [
        _Act(
          icon: Icons.undo,
          label: 'Hoàn tác',
          onTap: canUndo ? onUndo : null,
        ),
        _Act(
          icon: Icons.redo,
          label: 'Làm lại',
          onTap: canRedo ? onRedo : null,
        ),
        _Act(icon: Icons.backspace_outlined, label: 'Xoá', onTap: onErase),
        _Act(
          icon: notesOn ? Icons.edit : Icons.edit_outlined,
          label: 'Ghi chú',
          active: notesOn,
          badge: notesOn ? 'BẬT' : 'TẮT',
          badgeColor: notesOn ? s.primary : s.outline,
          onTap: onNotes,
        ),
        _Act(
          icon: Icons.lightbulb_outline,
          label: 'Gợi ý',
          badge: '$hintsLeft',
          badgeColor: hintsLeft > 0 ? s.tertiary : s.outline,
          onTap: hintsLeft > 0 ? onHint : null,
        ),
      ],
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badge,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final fg = !enabled
        ? s.onSurface.withValues(alpha: 0.35)
        : active
        ? s.primary
        : s.onSurfaceVariant;
    Widget ic = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: active ? s.primaryContainer : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: fg, size: 24),
    );
    if (badge != null) {
      ic = Badge(
        label: Text(badge!),
        backgroundColor: badgeColor,
        textColor: s.surface,
        offset: const Offset(6, -2),
        child: ic,
      );
    }
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ic,
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ban phim so 1-9, moi nut hien so con lai; du 9 thi mo va khoa.
class SudokuNumPad extends StatelessWidget {
  const SudokuNumPad({
    required this.remaining,
    required this.notesOn,
    required this.onDigit,
    super.key,
  });

  /// remaining[d-1] = so o con thieu cua chu so d.
  final List<int> remaining;
  final bool notesOn;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var d = 1; d <= 9; d++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: remaining[d - 1] <= 0 ? 0.3 : 1,
                child: Material(
                  color: notesOn ? s.surfaceContainerHigh : s.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: ValueKey('sudoku-pad-$d'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: remaining[d - 1] <= 0 ? null : () => onDigit(d),
                    child: SizedBox(
                      height: 58,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$d',
                            style: TextStyle(
                              fontSize: notesOn ? 20 : 24,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              color: notesOn
                                  ? s.onSurfaceVariant
                                  : s.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            remaining[d - 1] <= 0 ? '' : '${remaining[d - 1]}',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  (notesOn
                                          ? s.onSurfaceVariant
                                          : s.onPrimaryContainer)
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Danh sach chon do kho kem ky luc tung muc.
class SudokuLevelPicker extends StatelessWidget {
  const SudokuLevelPicker({
    required this.stats,
    required this.onPick,
    this.current,
    super.key,
  });

  final GameStats Function(SudokuLevel) stats;
  final ValueChanged<SudokuLevel> onPick;
  final SudokuLevel? current;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (k, l) in SudokuLevel.values.indexed)
          PopIn(
            trigger: l,
            duration: Duration(milliseconds: 220 + 60 * k),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Material(
                color: l == current
                    ? s.primaryContainer
                    : s.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: ValueKey('sudoku-level-${l.name}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onPick(l),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(levelIcon(l), size: 30, color: s.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.label, style: t.titleMedium),
                              Text(
                                _sub(stats(l)),
                                style: t.bodySmall?.copyWith(
                                  color: s.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.play_arrow_rounded, color: s.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _sub(GameStats st) {
    final best = st.best == null
        ? 'Chưa có kỷ lục'
        : 'Kỷ lục ${formatClock(st.best!)}';
    return '$best · Thắng ${st.won}/${st.played}';
  }
}

/// Bang ket qua sau van (thang hoac thua).
class SudokuResultPanel extends StatelessWidget {
  const SudokuResultPanel({
    required this.won,
    required this.seconds,
    required this.mistakes,
    required this.mistakeLimit,
    required this.hints,
    required this.best,
    required this.newRecord,
    required this.title,
    required this.actions,
    super.key,
  });

  final bool won;
  final int seconds;
  final int mistakes;
  final bool mistakeLimit;
  final int hints;
  final int? best;
  final bool newRecord;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return PopIn(
      child: Card(
        elevation: 0,
        color: won ? s.primaryContainer : s.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won ? Icons.emoji_events : Icons.heart_broken_outlined,
                size: 48,
                color: won ? s.onPrimaryContainer : s.onErrorContainer,
              ),
              const SizedBox(height: 6),
              Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
              if (newRecord) ...[
                const SizedBox(height: 6),
                PopIn(
                  duration: const Duration(milliseconds: 500),
                  child: Chip(
                    avatar: Icon(Icons.star_rounded, color: s.tertiary),
                    label: const Text('Kỷ lục mới!'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _row(
                context,
                Icons.timer_outlined,
                'Thời gian',
                formatClock(seconds),
              ),
              _row(
                context,
                Icons.close_rounded,
                'Lỗi',
                mistakeLimit ? '$mistakes/3' : '$mistakes',
              ),
              _row(context, Icons.lightbulb_outline, 'Gợi ý đã dùng', '$hints'),
              if (best != null)
                _row(
                  context,
                  Icons.workspace_premium_outlined,
                  'Kỷ lục',
                  formatClock(best!),
                ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData i, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(i, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(k)),
        Text(
          v,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
