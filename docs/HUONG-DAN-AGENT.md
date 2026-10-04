# Hướng dẫn cho agent làm việc trong Puzzle Hub

Dự án Flutter 3.47 tại thư mục chứa file này (git). Flutter: `$env:Path += ';E:\tools\flutter\bin'` (PowerShell). Đọc `CLAUDE.md`, `docs/BAT-DAU-O-DAY.md`, `.claude/skills/puzzle-hub-them-game/SKILL.md` trước. Ghi chú/UI tiếng Việt.

Mục tiêu CEO (04/10/2026): game còn thiếu rất nhiều tính năng, màn hình, animation, hiệu ứng. Nâng cấp toàn diện lên chất lượng game thương mại.

## Hạ tầng dùng chung (đã có)
- `lib/core/storage/progress_store.dart`: ProgressStore (stats, state, daily). Chỉ agent app-shell được thêm vào.
- `lib/core/storage/game_store.dart`: `GameStore(ref.read(progressStoreProvider), daily: widget.daily)` bọc ProgressStore, cùng API (loadState/saveState/clearState/recordStart/recordWin/recordScore/stats); chế độ thử thách ngày dùng khoá lưu riêng, `rngFor(id)` cho Random có seed cố định, `homeRoute`.
- `lib/core/ui/fx.dart`: `GameFx.tap/success/error` (rung), `Confetti`, `PopIn`, `Shake`, `WinBanner`.
- `lib/core/audio/sfx.dart`: `Sfx.play(SfxKind.x)`; mặc định no-op, agent app-shell cài âm thanh thật. Game cứ gọi.
- `lib/core/daily/daily_challenge.dart`: dateKey, dailyGameFor, dailySeed.
- `lib/games/game_registry.dart`: GameInfo có `dailyBuilder` (khoá ngày yyyyMMdd -> widget) và `howTo` (hướng dẫn ngắn).

## Luật
- Mỗi agent chỉ sửa thư mục của mình (`lib/games/<id>/**`, `test/games/<id>_*`). Registry: chỉ `Edit` đúng khối GameInfo của game mình (và thêm dòng import), cấm Write cả file. Không sửa pubspec.yaml, `lib/core/**`, `lib/features/**` (trừ agent app-shell): cần gói/hạ tầng mới thì ghi vào báo cáo.
- Nhiều agent chung một cây git. Cấm `git add -A`, `git commit -a`, `--no-verify`, `git push`, `git stash`, `git checkout`/`reset` file người khác. Commit: `git add <đường dẫn của mình>`, `git commit -m "feat(<game>): ..."` kèm dòng cuối `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Hook pre-commit chạy dart format + analyze toàn dự án: lỗi do file agent khác thì chờ 30-60 giây rồi thử lại, lỗi của mình thì sửa. Gặp `index.lock` thì thử lại.
- CẤM `flutter build`, `flutter run`, emulator, adb (chung thư mục build và một máy ảo). Kiểm bằng `dart format .`, `flutter analyze`, `flutter test` (viết test engine + widget test cho tính năng mới). Điều phối sẽ chạy thử trên máy ảo.
- Mã hoá: chữ tiếng Việt có dấu trong mã nguồn phải là UTF-8. Chỉ ghi file bằng công cụ Write/Edit; cấm `Get-Content | Set-Content` sửa file có dấu. Không đưa chữ cmdlet xoá file vào script PowerShell (bị chặn).
- Màu lấy từ `Theme.of(context).colorScheme` (sáng/tối). Layout chạy tốt ở rộng 360-440, vẫn dùng được ở màn lớn (ConstrainedBox). Icon dùng Material/lucide, không chữ emoji làm icon chính.
- Engine thuần Dart (không import flutter) có test; UI ở presentation. Lưu tiến độ qua GameStore; JSON có thể hỏng thì try/catch rồi bắt đầu ván mới.
- Animation: mượt, có ý nghĩa (AnimatedContainer/AnimatedSwitcher/TweenAnimationBuilder/AnimationController), tôn trọng `MediaQuery.disableAnimations`. Gọi `GameFx.*` và `Sfx.play(...)` ở sự kiện chính. Thắng: `WinBanner`/`Confetti`.
- Không gọi `saveState` trong `dispose` (làm ValueNotifier màn chính nổ giữa lúc dựng).
- Ghi tiến độ dần vào `docs/tien-do/<id>.md`: mỗi mốc một dòng `TIEN-DO: ...`; xong ghi `XONG: ...`, cần CEO ghi `CAN CEO: ...`. Cuối cùng viết `docs/games/<id>.md` (máy đọc, ngắn: tính năng, cấu trúc, khoá lưu, bẫy).
- Báo cáo cuối ≤ 8 dòng: đã làm gì, số test, SHA commit, việc dở/cần CEO. Không dán mã.

## Chế độ thử thách ngày (game có cờ DAILY)
Màn nhận `const XScreen({super.key, this.daily})`, `final String? daily;` (yyyyMMdd). Dùng `GameStore`; sinh đề bằng `rng: _store.rngFor(_id)` để mọi máy cùng đề; Back về `context.go(_store.homeRoute)`; nút ván mới ở chế độ ngày = chơi lại cùng đề, ẩn chọn độ khó; thắng gọi `_store.recordWin(_id, score: ...)` (GameStore tự ghi hoàn thành ngày); đặt `dailyBuilder: (d) => XScreen(daily: d)` trong registry.
