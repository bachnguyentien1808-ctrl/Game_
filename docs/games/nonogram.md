# nonogram (máy đọc)
Tính năng: 24 tranh (gói 5x5, 8x8, 10x10, 12x12), màn chọn có thumbnail/sao/tiến độ gói; kéo tô hàng loạt theo hàng/cột (Listener), nút Tô/X/Xem (Xem = InteractiveViewer pan+zoom), gợi ý mờ khi đủ, tô sáng hàng/cột đang chạm, Kiểm lỗi (đỏ), undo/redo theo nét, đồng hồ, gợi ý tối đa 3 (khoá ô), chớp hàng/cột xong, thắng thì tranh chuyển màu + WinBanner.
Cấu trúc: domain/puzzles.dart (dữ liệu, top/bottom = màu nội suy theo hàng), nonogram_engine.dart (NonogramPuzzle, NonogramGame), nonogram_progress.dart (lưu), presentation/nonogram_screen.dart (chọn màn), nonogram_play.dart, nonogram_thumb.dart.
Khoá lưu: GameStore 'nonogram' = {v:2, saves:{idx:{g,t,h,m,l}}, best:{idx:{t,s}}}; idx = vị trí trong nonogramPuzzles, KHÔNG đổi thứ tự/chèn giữa danh sách (chỉ thêm cuối).
Sao: 3 nếu giây <= size*size*2.5, trừ 1 nếu quá giờ, trừ 1 nếu >3 lỗi hoặc >1 gợi ý.
Bẫy: state v1 cũ bị bỏ (không đọc). recordWin(id) không có score vì ký lục theo từng tranh nằm trong state.
