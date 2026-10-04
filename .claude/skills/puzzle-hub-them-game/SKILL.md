---
name: puzzle-hub-them-game
description: Thêm một game mới vào Puzzle Hub (Flutter) theo cấu trúc domain/presentation và registry, kèm test và kiểm tra trên web 375px.
---

1. Tạo `lib/games/<id>/domain/<id>_engine.dart`: logic thuần Dart (không import flutter), có hàm kiểm thắng/thua, nhận `Random? rng` để test tất định.
2. Tạo `lib/games/<id>/presentation/<id>_screen.dart`: `Scaffold` có `BackButton(onPressed: () => context.go('/'))`, nút làm lại, `ConstrainedBox(maxWidth: ~440)`, dùng `Theme.of(context).colorScheme` (không hard-code màu).
2b. Lưu tiến độ: màn là `ConsumerStatefulWidget`, `ref.read(progressStoreProvider)`; engine có `toJson`/`fromJson`; `loadState` ở `initState`, `saveState` sau mỗi nước, `recordStart` khi ván mới, `recordWin(score:, lowerIsBetter:)` + `clearState` khi thắng; thêm `bestKind` ở `GameInfo`.
3. Đăng ký một `GameInfo` trong `lib/games/game_registry.dart` (id, title, subtitle tiếng Việt, icon Material).
4. Viết test engine trong `test/games/`.
5. `dart format . && flutter analyze && flutter test`.
6. `flutter build web --release`, phục vụ bằng http.server cổng 3300, duyệt ở viewport 375x812; chờ 3-4 giây sau khi load rồi mới gửi phím/click.
7. Commit `feat(games): ...`, add từng đường dẫn, push.
Cẩn thận mã hoá: chỉ ghi file bằng Write/Edit.