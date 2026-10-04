# minesweeper (Do min)

- Engine: lib/games/minesweeper/domain/minesweeper_engine.dart. MineLevel (easy 9x9/10, medium 16x16/40, hard 16x30/99, custom), validateConfig (hang 5-30, cot 5-40, min 1..hang*cot-9), Minesweeper.custom/daily, open() va chord() tra ve danh sach o vua mo, flagAllMines, safeHint (2 luat: so == o chua mo ke => mine; so == mine biet => con lai an toan; khong tin co).
- UI: presentation/minesweeper_screen.dart. Ban lon dung InteractiveViewer, o toi thieu 32px. Moi o la _Tile giu "hinh hien thi" rieng de tre (song mo, mine no lan luot, thang cam co lan luot). disableAnimations => bo tre.
- Khoa luu: state `minesweeper` (engine + seconds, moved, hints, level); `minesweeper.prefs` (muc cuoi + cau hinh tuy chinh, khong dung o che do ngay). Thong ke: `minesweeper.easy|medium|hard` (ky luc theo muc); `minesweeper` chung chi nhan ky luc cua muc De. Tuy chinh khong co ky luc.
- Daily: Minesweeper.daily(rng: store.rngFor) muc Vua, o khoi dau mo san; dong ho chi chay sau thao tac dau.
- Bay: hint toi da 3/van, khong dem khi khong suy ra duoc. Dong ho dung khi app khong o resumed.
