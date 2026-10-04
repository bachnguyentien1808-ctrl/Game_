# Puzzle Hub

Tổng hợp game trí tuệ (Sudoku và các game tiếp theo), Flutter 3.47 / Dart 3.13.

## Cấu trúc
- `lib/core/` theme, router (go_router)
- `lib/features/` màn hình chung (home)
- `lib/games/<game>/{domain,presentation}` mỗi game một thư mục; engine thuần Dart ở `domain`, giao diện ở `presentation`
- `lib/games/game_registry.dart` thêm game mới = thêm một dòng

## Lệnh
```
flutter pub get
flutter run -d windows
dart format . && flutter analyze && flutter test
```

## Git
- Nhánh `main`, commit theo `<type>(<scope>): mô tả` (xem `.gitmessage`)
- Hook `githooks/pre-commit` (bật bằng `git config core.hooksPath githooks`): chặn token/khoá lộ, kiểm format + analyze
- CI: `.github/workflows/ci.yml`
