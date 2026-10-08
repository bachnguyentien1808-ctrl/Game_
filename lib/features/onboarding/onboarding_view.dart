import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/game_logo.dart';
import 'package:puzzle_hub/features/common/shell_widgets.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const _slideColors = [Candy.orange, Candy.red, Candy.green];

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
    final t = Theme.of(context).textTheme;
    final last = _i == _slides.length - 1;
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ContentWidth(
              maxWidth: 520,
              child: Column(
                children: [
                  const SizedBox(height: 56),
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
                                child: i == 0
                                    ? BrandLogo(
                                        height:
                                            (MediaQuery.sizeOf(context).height *
                                                    .24)
                                                .clamp(100.0, 190.0),
                                      )
                                    : _Bubble(
                                        icon: sl.icon,
                                        colors:
                                            _slideColors[i %
                                                _slideColors.length],
                                      ),
                              ),
                              const SizedBox(height: 32),
                              CandyFrame(
                                padding: 5,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: const Color(0xFFFFF6E3),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      16,
                                      18,
                                      18,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          sl.title,
                                          style: t.headlineSmall?.copyWith(
                                            color: Candy.brown,
                                            fontWeight: FontWeight.w900,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          sl.body,
                                          style: t.bodyLarge?.copyWith(
                                            color: const Color(0xFF9A6B3C),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                          width: k == _i ? 28 : 12,
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: k == _i
                                  ? Candy.orange
                                  : const [Candy.cream, Candy.creamDeep],
                            ),
                            border: Border.all(color: Candy.gold, width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 240,
                        minHeight: 58,
                      ),
                      child: CandyButton(
                        onPressed: _next,
                        colors: last ? Candy.green : Candy.orange,
                        radius: 22,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        child: Text(
                          last ? 'Bắt đầu chơi' : 'Tiếp',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Nut Bo qua o goc tren ben phai cua ca man hinh.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                opacity: last ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                  child: CandyButton(
                    onPressed: last ? null : widget.onDone,
                    radius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: const Text('Bỏ qua'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hinh tron bong bay minh hoa mot trang gioi thieu.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon, required this.colors});

  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      height: 148,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Candy.gold, width: 5),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(color: Candy.deep(colors), offset: const Offset(0, 7)),
          const BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 14),
            blurRadius: 12,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CandyGloss(radius: 70, opacity: 0.4),
          const SizedBox.shrink(),
          Icon(
            icon,
            size: 76,
            color: Colors.white,
            shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)],
          ),
        ],
      ),
    );
  }
}
