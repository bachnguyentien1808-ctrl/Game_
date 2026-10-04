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

## 3. Trạng thái (04/10/2026)
- 7 game: Sudoku (3 độ khó, gợi ý, tô cùng số), 2048, Nonogram (3 màn), Tìm cặp, Dò mìn 9x9 (mở/cắm cờ, đồng hồ), Tắt đèn 5x5, Xếp số 4x4. Engine thuần Dart có test (13 test).
- Lưu tiến độ: `lib/core/storage/progress_store.dart` (shared_preferences). Khoá `state.<id>` = ván đang chơi, `stats.<id>` = đã chơi/thắng/kỷ lục. Màn chính hiện thống kê, chip "Chơi tiếp", menu "Xóa toàn bộ tiến độ". Đã kiểm trên máy ảo: tắt hẳn app rồi mở lại vẫn còn.
- Mỗi màn game đọc `loadState` ở `initState`, `saveState` sau mỗi nước, `recordWin`/`clearState` khi thắng. Không gọi `saveState` trong `dispose` (làm `ValueNotifier` của màn chính nổ giữa lúc dựng).
- Chưa có: ghi chú Sudoku (bút chì), đồng hồ Sudoku, âm thanh/rung, đa ngôn ngữ, icon/splash, thống kê chi tiết, chế độ tối/sáng thủ công, đồng bộ đám mây, TestFlight/Play.
- Việc đề xuất tiếp: Kakuro, Word search, Hanoi, Nonogram nhiều màn hơn, thử thách mỗi ngày + chuỗi ngày, icon app.

## 4. Kinh nghiệm đã trả giá
- `flutter run -d web-server` (debug/DDC) bị kẹt màn trắng trong trình duyệt nhúng; dùng bản release + http.server.
- `google_fonts` + `ThemeData.copyWith(textTheme:)` lỗi kiểu TextTheme với Flutter 3.47: bỏ google_fonts, dùng font mặc định.
- Map hằng với khoá `LogicalKeyboardKey` không `const` được: dùng `static final`.
- Lint: `very_good_analysis` nghiêm; đã tắt vài luật ồn trong `analysis_options.yaml`.
- Công cụ PowerShell của Claude chặn cả lệnh có chữ xoá-file kiểu cmdlet lạ trong nội dung script: tránh xoá, ghi đè file thay thế.
- Gửi phím vào trang vừa load khi Flutter chưa khởi động sẽ mất: chờ 3-4 giây.
- Tọa độ click trong trình duyệt nhúng phải lấy từ ảnh chụp ngay trước đó.
- CEO: icon UI dùng lucide/Material, logo ALODEV là `AD` không phải `aa`; không dùng `AlodevWorkwatch-*` làm tên repo.