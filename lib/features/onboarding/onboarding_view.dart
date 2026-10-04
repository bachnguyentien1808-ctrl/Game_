import 'package:flutter/material.dart';
import 'package:puzzle_hub/features/common/shell_widgets.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    Icons.extension_rounded,
    'Chào mừng tới Puzzle Hub',
    'Nhiều trò chơi trí tuệ trong một ứng dụng: Sudoku, 2048, Nonogram, Dò mìn và hơn nữa.',
  ),
  _Slide(
    Icons.local_fire_department_rounded,
    'Thử thách mỗi ngày',
    'Mỗi ngày một câu đố, mọi người cùng một đề. Hoàn thành liên tục để giữ chuỗi ngày.',
  ),
  _Slide(
    Icons.insights_rounded,
    'Lưu tự động, xem tiến bộ',
    'Ván dở được lưu lại. Thống kê, kỷ lục và chuỗi ngày nằm ở màn Thống kê.',
  ),
];

/// Gioi thieu lan dau: 3 trang, nut Bo qua / Tiep / Bat dau.
class OnboardingView extends StatefulWidget {
  const OnboardingView({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_i == _slides.length - 1) {
      widget.onDone();
      return;
    }
    _page.nextPage(
      duration: animationsOff(context)
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final last = _i == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 520,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: last ? null : widget.onDone,
                    child: const Text('Bỏ qua'),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _page,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (_, i) {
                    final sl = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            key: ValueKey(i),
                            tween: Tween(begin: 0.7, end: 1),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutBack,
                            builder: (_, v, child) =>
                                Transform.scale(scale: v, child: child),
                            child: IconTile(icon: sl.icon, size: 132),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            sl.title,
                            style: t.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            sl.body,
                            style: t.bodyLarge?.copyWith(
                              color: s.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var k = 0; k < _slides.length; k++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: k == _i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: k == _i ? s.primary : s.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(last ? 'Bắt đầu chơi' : 'Tiếp'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
