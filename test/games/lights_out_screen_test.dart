import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/games/lights_out/domain/lights_out_engine.dart';
import 'package:puzzle_hub/games/lights_out/presentation/lights_out_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => GameFx.haptics.value = false);

  Future<GameStore> store() async {
    SharedPreferences.setMockInitialValues({});
    return GameStore(ProgressStore(await SharedPreferences.getInstance()));
  }

  Widget host(GameStore st, LightsSession s) => MaterialApp(
    home: LightsOutPlay(session: s, store: st, onExit: () {}),
  );

  testWidgets('khoi phuc van dang choi va luu lai sau khi bam', (t) async {
    final st = await store();
    final g = LightsOut([
      [true, false, false],
      [false, true, false],
      [false, false, false],
    ], moves: 3);
    await st.saveState(lightsOutId, g.toJson());
    await t.pumpWidget(host(st, const LightsSession.random(3, resume: true)));
    expect(find.text('Lượt 3'), findsOneWidget);
    expect(find.text('Tối ưu ${g.optimal}'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('lo_cell_0_0')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Lượt 4'), findsOneWidget);
    expect(st.loadState(lightsOutId)!['moves'], 4);

    // Hoan tac dua ve 3 luot; goi y tru so lan con lai.
    await t.tap(find.byTooltip('Hoàn tác'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Lượt 3'), findsOneWidget);
    await t.tap(find.byTooltip('Gợi ý (còn 3)'));
    await t.pump();
    expect(find.byTooltip('Gợi ý (còn 2)'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
  });

  testWidgets('thang man: ghi sao, mo khoa va xoa trang thai', (t) async {
    final st = await store();
    await t.pumpWidget(host(st, const LightsSession.level(1)));
    final g = LightsOut.fromJson(st.loadState('lights_out.level')!);
    // Bam theo loi giai toi uu.
    for (final i in g.peekHintAll()) {
      await t.tap(find.byKey(ValueKey('lo_cell_${i ~/ 3}_${i % 3}')));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(seconds: 6));
    expect(find.text('Tắt hết đèn!'), findsOneWidget);
    expect(loadLevelStars(st)[0], 3);
    expect(st.loadState('lights_out.level'), isNull);
    expect(st.stats(lightsOutId).won, 1);

    await t.pumpWidget(const SizedBox());
  });
}

extension on LightsOut {
  /// Toan bo loi giai toi uu tu bang hien tai (cho test).
  List<int> peekHintAll() {
    final copy = LightsOut([for (final r in cells) List.of(r)]);
    final out = <int>[];
    while (!copy.solved) {
      final h = copy.peekHint()!;
      out.add(h);
      copy.press(h ~/ copy.size, h % copy.size);
    }
    return out;
  }
}
