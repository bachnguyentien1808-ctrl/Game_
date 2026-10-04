# Puzzle Hub - cửa vào cho Claude

Trả lời CEO bằng **tiếng Việt**, báo ngắn: kết luận + việc CEO phải tự làm. Đọc `docs/BAT-DAU-O-DAY.md` trước khi làm.

## Luật cứng
- Không `git add -A` / `git commit -a`: add từng đường dẫn.
- Không bao giờ dùng token/mật khẩu CEO dán vào chat. Đăng nhập GitHub bằng `gh auth login` cục bộ; nhắc CEO thu hồi token đã lộ.
- Tiếng Việt trong mã nguồn phải là UTF-8 không BOM. Cấm sửa file bằng `Get-Content -Raw | Set-Content` trong PowerShell 5.1 (làm hỏng dấu); dùng công cụ Edit/Write hoặc `[IO.File]::WriteAllText` với `UTF8Encoding($false)`.
- Trước commit: `dart format . && flutter analyze && flutter test` (hook `githooks/pre-commit` cũng chặn).
- Thêm game mới = thư mục `lib/games/<game>/{domain,presentation}` + 1 dòng trong `lib/games/game_registry.dart` + test engine. Engine thuần Dart, không import Flutter.
- Skill: `.claude/skills/puzzle-hub-them-game/SKILL.md`.