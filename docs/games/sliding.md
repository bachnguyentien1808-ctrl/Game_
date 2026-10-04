# sliding (Xep so)

Tinh nang: 3x3/4x4/5x5 (sheet Tuy chon; DAILY co dinh 4x4, an chon), o truot AnimatedPositioned (chuoi hang/cot, vuot huong), xao tron ban dau co animation, o ve dung cho doi mau + nay, che do Anh (5 tranh CustomPaint trong sliding_art.dart, bat/tat so, giu nut mat de xem goc), dong ho + tam dung (tu tam dung khi roi app), hoan tac nhieu buoc, goi y 3 lan/van, thang: o sang lan luot + WinBanner (luot/gio/ky luc).

Cau truc: domain/sliding_engine.dart (SlidingPuzzle: generate theo rng, isSolvable, tap, slide(SlideDir), undo qua history vi tri o trong, solve IDA* Manhattan+linear conflict, hint: 3x3 toi uu, 4x4/5x5 gioi han node roi greedy nhin truoc 5 buoc). presentation/sliding_screen.dart, sliding_art.dart.

Khoa luu: state `sliding` (+ `daily.sliding.<ngay>`): tiles,size,moves,history,mode,art,nums,ms,hints. Tuy chon: state `sliding.prefs`. Stats: `sliding` (tong, best=luot 4x4), `sliding.<n>` (best luot), `sliding.<n>.t` (best giay).

Bay: hint 4x4/5x5 khong dam bao toi uu; test widget phai pump qua thoi gian xao tron/quet thang de khong con Timer; khong goi saveState trong dispose.
