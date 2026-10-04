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

## 3. Trạng thái (04/10/2026)
- 4 game: Sudoku, 2048, Nonogram (3 màn), Tìm cặp (4x4). Engine có test; UI duyệt bằng mắt trên web 375px: 2048 chơi được, Nonogram hiện đúng, Tìm cặp mới xem bố cục.
- Chưa có: lưu tiến độ (shared_preferences đã có trong pubspec), ghi chú Sudoku, gợi ý, đồng hồ, âm thanh, đa ngôn ngữ, icon/splash, Android emulator, TestFlight/Play.
- Việc đề xuất tiếp: lưu tiến độ + thống kê, thêm game (Minesweeper, Kakuro, Lights Out, Sliding puzzle, Word search), icon app.

## 4. Kinh nghiệm đã trả giá
- `flutter run -d web-server` (debug/DDC) bị kẹt màn trắng trong trình duyệt nhúng; dùng bản release + http.server.
- `google_fonts` + `ThemeData.copyWith(textTheme:)` lỗi kiểu TextTheme với Flutter 3.47: bỏ google_fonts, dùng font mặc định.
- Map hằng với khoá `LogicalKeyboardKey` không `const` được: dùng `static final`.
- Lint: `very_good_analysis` nghiêm; đã tắt vài luật ồn trong `analysis_options.yaml`.
- Công cụ PowerShell của Claude chặn cả lệnh có chữ xoá-file kiểu cmdlet lạ trong nội dung script: tránh xoá, ghi đè file thay thế.
- Gửi phím vào trang vừa load khi Flutter chưa khởi động sẽ mất: chờ 3-4 giây.
- Tọa độ click trong trình duyệt nhúng phải lấy từ ảnh chụp ngay trước đó.
- CEO: icon UI dùng lucide/Material, logo ALODEV là `AD` không phải `aa`; không dùng `AlodevWorkwatch-*` làm tên repo.