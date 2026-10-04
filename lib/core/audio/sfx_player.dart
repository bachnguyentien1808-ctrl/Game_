import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';

/// Phat am hieu ung that tu assets/sfx/*.wav (sinh boi tools/gen_sfx.dart).
/// Moi loai am giu toi da [_voices] AudioPlayer xoay vong de phat chong nhau.
/// Moi loi plugin (vd chay trong test, nen tang thieu plugin) deu bi nuot:
/// am thanh khong bao gio duoc lam sap game.
class SfxEngine {
  SfxEngine._();

  static final SfxEngine instance = SfxEngine._();

  /// Bat/tat am thanh (man Cai dat ghi vao day).
  static final ValueNotifier<bool> enabled = ValueNotifier(true);

  static const _voices = 3;
  final Map<SfxKind, List<AudioPlayer>> _pool = {};
  final Map<SfxKind, int> _next = {};
  bool _broken = false;

  static String assetOf(SfxKind k) => 'sfx/${k.name}.wav';

  /// Gan [Sfx.player] va nap truoc file am. Goi mot lan o main().
  static Future<void> install() async {
    Sfx.player = instance.play;
    try {
      await AudioCache.instance.loadAll([
        for (final k in SfxKind.values) assetOf(k),
      ]);
    } on Object catch (e) {
      debugPrint('SfxEngine: khong nap duoc am thanh: $e');
    }
  }

  void play(SfxKind kind) {
    if (!enabled.value || _broken) return;
    try {
      final list = _pool.putIfAbsent(kind, () => []);
      final i = _next[kind] ?? 0;
      _next[kind] = (i + 1) % _voices;
      if (list.length <= i) {
        list.add(
          AudioPlayer(playerId: 'sfx_${kind.name}_$i')
            ..setReleaseMode(ReleaseMode.stop).catchError((Object _) {}),
        );
      }
      final p = list[i];
      unawaited(
        p
            .stop()
            .then((_) => p.play(AssetSource(assetOf(kind)), volume: 0.8))
            .catchError(_onError),
      );
    } on Object catch (e) {
      _onError(e);
    }
  }

  void _onError(Object e) {
    if (e is MissingPluginException) _broken = true;
    debugPrint('SfxEngine: $e');
  }
}
