# Bắt đầu ở đây (máy mới)

## 1. Cài môi trường (Windows)
```
git clone https://github.com/trancongthangvn/puzzle-hub.git
git clone https://github.com/flutter/flutter.git -b stable --depth 1 E:\tools\flutter
setx PATH "%PATH%;E:\tools\flutter\bin"        # mở terminal mới sau đó
git config --global --add safe.directory E:/tools/flutter
cd puzzle-hub
git config core.hooksPath githooks              # BẮT BUỘC, hook không đi theo clone
git config commit.template .gitmessage
flutter pub get
flutter test
```
Build Windows desktop cần bật Developer Mode: `start ms-settings:developers`.
Đăng nhập GitHub: `gh auth login` (không dán token vào chat).

## 2. Duyệt nhanh trên "máy ảo"
Chưa có Android emulator. Cách duyệt nhanh: bản web release trong khung điện thoại 375x812.
```
flutter build web --release
python -m http.server 3300 --bind 127.0.0.1 --directory build/web
```
Mở http://localhost:3300 . Mẫu cấu hình preview: `docs/launch.json.mau` (preview_start đọc `.claude/launch.json` của thư mục mở phiên).

### Máy ảo Android (đã chạy được 04/10/2026)
AVD `puzzle_pixel` (Pixel 6, Android 35 google_apis x86_64) tạo từ SDK có sẵn ở `%LOCALAPPDATA%\Android\Sdk`.
```
%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe -avd puzzle_pixel
# PowerShell, trong thư mục dự án:
$env:JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=C:\gtmp -Djava.net.preferIPv4Stack=true"   # tạo C:\gtmp trước
$env:ANDROID_HOME="$env:LOCALAPPDATA\Android\Sdk"
flutter run -d emulator-5554
```
Đường dẫn user có dấu cách ("TRAN CONG THANG") nên Gradle cần `JAVA_TOOL_OPTIONS` ở trên, nếu không báo `Unable to establish loopback connection`. `android/gradle.properties` đã có `kotlin.incremental=false` (project ở ổ E, pub cache ở ổ C làm Kotlin lỗi cache).
Công cụ Terminal của app Claude có thể không khởi động (thiếu `terminal-shell-integration`): chạy lệnh Gradle bằng PowerShell tool với sandbox tắt.
Chụp màn hình/kiểm: `adb exec-out screencap -p`, `adb shell uiautomator dump`, đọc prefs bằng `adb shell run-as vn.alodev.puzzle_hub cat shared_prefs/FlutterSharedPreferences.xml`.

## 3. Trạng thái (07/10/2026)
- 8 game: Sudoku, 2048, Nonogram, Tìm cặp, Dò mìn, Tắt đèn, Xếp số, Kakuro. Engine thuần Dart có test; đăng ký ở `lib/games/game_registry.dart`.
- Lưu tiến độ: `lib/core/storage/progress_store.dart` (shared_preferences): `state.<id>` ván dở, `stats.<id>` đã chơi/thắng/kỷ lục/chuỗi thắng, `score.total` + `score.game.<id>` điểm, `tutorial.<id>` đã xem hướng dẫn.
- Điểm số: `lib/core/score/scoring.dart` (nhanh thì cao, chậm giảm dần, sàn 25%, mỗi lỗi -5%, mỗi gợi ý -8%). Mỗi game gọi `GameStore.awardPoints` đúng một lần khi thắng và truyền `points:` vào `WinBanner`. Ô điểm trên AppBar: `lib/core/ui/score_chip.dart`.
- Hướng dẫn + chú thích từng game: `lib/features/howto/game_tutorials.dart` (test bắt buộc mỗi game trong registry phải có). Tự mở lần đầu qua `GameIntro` trong router; nút "?" trên AppBar.
- Giao diện: bộ kẹo `lib/core/ui/candy.dart` + bộ kính mờ `lib/core/ui/glass.dart` (đổi màu theo ngày/chiều/đêm). Logo: `lib/core/ui/game_logo.dart` (+ `assets/images/logo*.webp`).
- Nền: `CandyBackground` (màn ngoài, chuyển động) và `GameBackdrop` (trong game, đứng yên). Buổi trong ngày: `lib/core/theme/day_phase.dart`; Cài đặt Sáng = ban ngày, Tối = ban đêm, Tự động = theo giờ (05:30-16:29 ngày, 16:30-18:59 chiều, còn lại đêm). Ảnh nền `assets/images/bg_*.webp` đều là ảnh người dùng cung cấp, không tự sinh; test tắt chuyển động qua `test/flutter_test_config.dart`.
- Chưa có: đa ngôn ngữ, icon app/splash theo logo mới (icon hiện vẫn là mảnh ghép), đồng bộ đám mây, TestFlight/Play.
- Việc đề xuất tiếp: Word search, Hanoi, thưởng điểm giữa chừng cho Nonogram/Kakuro, ảnh nền chiều/đêm riêng cho từng cảnh.

## 4. Kinh nghiệm đã trả giá
- `flutter run -d web-server` (debug/DDC) bị kẹt màn trắng trong trình duyệt nhúng; dùng bản release + http.server.
- `google_fonts` + `ThemeData.copyWith(textTheme:)` lỗi kiểu TextTheme với Flutter 3.47: bỏ google_fonts, dùng font mặc định.
- Map hằng với khoá `LogicalKeyboardKey` không `const` được: dùng `static final`.
- Lint: `very_good_analysis` nghiêm; đã tắt vài luật ồn trong `analysis_options.yaml`.
- Công cụ PowerShell của Claude chặn cả lệnh có chữ xoá-file kiểu cmdlet lạ trong nội dung script: tránh xoá, ghi đè file thay thế.
- Gửi phím vào trang vừa load khi Flutter chưa khởi động sẽ mất: chờ 3-4 giây.
- Tọa độ click trong trình duyệt nhúng phải lấy từ ảnh chụp ngay trước đó.
- CEO: icon UI dùng lucide/Material, logo ALODEV là `AD` không phải `aa`; không dùng `AlodevWorkwatch-*` làm tên repo.