import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/theme/day_phase.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

void main() {
  DayPhase at(int h, int m) => DayPhase.at(DateTime(2026, 10, 7, h, m));

  test('Buoi theo gio: sang, chieu, toi', () {
    expect(at(5, 29), DayPhase.night);
    expect(at(5, 30), DayPhase.day);
    expect(at(12, 0), DayPhase.day);
    expect(at(16, 29), DayPhase.day);
    expect(at(16, 30), DayPhase.dusk);
    expect(at(18, 59), DayPhase.dusk);
    expect(at(19, 0), DayPhase.night);
    expect(at(0, 0), DayPhase.night);
  });

  test('Hau to anh nen va giao dien toi', () {
    expect(DayPhase.day.suffix, '');
    expect(DayPhase.dusk.suffix, '_dusk');
    expect(DayPhase.night.suffix, '_night');
    expect(DayPhase.day.isDark, isFalse);
    expect(DayPhase.dusk.isDark, isTrue);
    expect(DayPhase.night.isDark, isTrue);
  });

  test('Chon anh nen: man hinh chinh va game dung anh co san', () {
    const sky = 'assets/images/bg_sky.webp';
    const game = 'assets/images/bg_game.webp';
    expect(BackdropAssets.resolve(sky, DayPhase.day), sky);
    expect(
      BackdropAssets.resolve(sky, DayPhase.dusk),
      'assets/images/bg_sky_dusk3.webp',
    );
    expect(
      BackdropAssets.resolve(sky, DayPhase.night),
      'assets/images/bg_sky_night.webp',
    );
    expect(BackdropAssets.resolve(game, DayPhase.day), game);
    expect(
      BackdropAssets.resolve(game, DayPhase.dusk),
      'assets/images/bg_game_dusk.webp',
    );
    expect(
      BackdropAssets.resolve(game, DayPhase.night),
      'assets/images/bg_game_night.webp',
    );
  });
}
