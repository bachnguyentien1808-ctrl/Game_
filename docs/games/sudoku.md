# sudoku (máy đọc)

## Tính năng
- 4 mức: Dễ 38 / Vừa 46 / Khó 52 / Chuyên gia ~58 ô trống. Màn chọn độ khó (chưa có ván) + sheet "Ván mới", kèm kỷ lục, thắng/chơi từng mức.
- Thử thách ngày: `SudokuScreen(daily: yyyyMMdd)`, mức Vừa cố định (`dailyLevel`), seed = `_store.rngFor('sudoku')!.nextInt(1<<31)`.
- Đồng hồ (ValueNotifier, không dựng lại bàn), tạm dừng che bàn (nút, phím Space/P, tự dừng khi app ra nền).
- Lỗi tối đa 3 -> thua, màn kết thúc (chơi tiếp bỏ giới hạn / chơi lại đề / ván mới). Tắt giới hạn trong menu.
- Hoàn tác/làm lại nhiều bước (200), ghi chú bút chì 3x3, tự xoá ghi chú ở ô + ô liên quan khi đặt số.
- Gợi ý 3 lượt/ván, có giải thích (sửa ô sai > suy luận tại ô chọn > suy luận bất kỳ > lộ đáp án). Ô gợi ý bị khoá, undo bỏ qua.
- Bàn phím số đếm số còn lại, mờ + khoá khi đủ 9. Tô hàng/cột/khối, số trùng, ô sai đỏ, ô gợi ý + đơn vị suy luận.
- Phím máy tính: 1-9/numpad, 0/Backspace/Delete xoá, mũi tên, N ghi chú, H gợi ý, Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z.
- Hiệu ứng: PopIn số, viền chọn trượt + nhịp, sóng sáng khi xong hàng/cột/khối và toàn bàn khi thắng, Shake + rung khi sai, WinBanner rồi bảng kết quả, fade khi đổi ván. Tôn trọng disableAnimations.

## Cấu trúc
- `domain/sudoku_engine.dart`: SudokuLevel, tìm kiếm bitmask + MRV, `generateLevel(level, seed:)` (tối đa 24 lần thử, chấm bằng solver). Đo: tối đa ~20ms (expert) trên VM -> sinh đồng bộ, không isolate.
- `domain/sudoku_solver.dart`: naked/hidden single, `nextStep`, `stepAt`, `solveLogically`, `rate`.
- `domain/sudoku_game.dart`: trạng thái ván, undo/redo, ghi chú, lỗi, gợi ý, JSON.
- `presentation/sudoku_screen.dart` (luồng), `sudoku_board.dart` (bàn + painter), `sudoku_controls.dart` (nút, bàn phím số, chọn mức, bảng kết quả).

## Khoá lưu
- `state.sudoku` (ván thường), `state.daily.sudoku.<ngày>` (qua GameStore). JSON: p/s/v chuỗi 81 số, n ghi chú, hi ô gợi ý, lv, m, h, t, ml.
- `stats.sudoku` tổng + `stats.sudoku.<easy|medium|hard|expert>` (giây, thấp hơn tốt hơn). Ngày: chỉ completeDaily.
- `state.sudoku.cfg` = {ml: bool} giới hạn lỗi (ghi thẳng ProgressStore).

## Bẫy
- Widget test: bàn có viền nhịp lặp -> không dùng pumpAndSettle; AnimatedSwitcher cần pump() rồi pump(400ms).
- Ván thua/thắng đã clearState; mở lại sẽ ra màn chọn mức (thường) hoặc đề ngày từ đầu.
