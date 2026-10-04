/// Cac loai am thanh hieu ung. Game goi `Sfx.play(SfxKind.x)`; phan phat am
/// that duoc nap qua [Sfx.player] (agent app-shell cai dat that, mac dinh no-op).
enum SfxKind { tap, place, erase, merge, flip, match, success, error, win }

abstract final class Sfx {
  /// Ham phat am; mac dinh khong lam gi. App-shell gan ham that khi khoi dong.
  static void Function(SfxKind kind) player = (_) {};

  static void play(SfxKind kind) => player(kind);
}
