# Tiến độ: sudoku

Pham vi: lib/games/sudoku/**, test/games/sudoku_*, khoi GameInfo 'sudoku'.

## Quyết định
- Engine bitmask + MRV de sinh de nhanh, sinh dong bo neu do < 300ms (do trong test).
- Trang thai van o domain (SudokuGame: undo/redo, ghi chu, loi, goi y) de test thuan Dart.
- Ky luc theo do kho: id stats 'sudoku.easy|medium|hard|expert' + 'sudoku' tong.
- Che do ngay: do kho Vua co dinh, seed = rngFor(id).nextInt.
- Cai dat (gioi han loi) luu o ProgressStore state 'sudoku.cfg'.

TIEN-DO: bat dau, doc huong dan + ma cu.
TIEN-DO: engine bitmask+MRV, bo giai naked/hidden single (cham do kho, goi y giai thich), SudokuGame (undo/redo, ghi chu, loi, goi y, json). 24 test xanh. Do sinh de: max ~21ms (expert) -> sinh dong bo, khong can isolate.
Tiep theo: viet lai presentation/sudoku_screen.dart (ConsumerStatefulWidget, GameStore, daily), widget test, registry howTo+dailyBuilder.
TIEN-DO: man choi viet lai (board/controls/screen), daily, registry howTo+dailyBuilder (khoi registry da lot vao commit ebd484a cua nonogram). 31 test sudoku, toan bo 127 xanh, analyze sach.
XONG: sudoku thuong mai hoa; docs/games/sudoku.md.
