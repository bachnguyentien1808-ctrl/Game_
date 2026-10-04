# kakuro (may doc)

- Id `kakuro`, DAILY co (`KakuroScreen(daily: d)`, muc Vua 6x6, de theo `rngFor`).
- Engine `lib/games/kakuro/domain/kakuro_engine.dart` (thuan Dart): `KakuroPuzzle` luoi size=n+1, hang/cot 0 den. `generate(n, density, rng)`: bo cuc ngau nhien -> lap chuyen den o co doan ngang/doc <2 -> bo neu < 45% o trang -> quay lui dien chu so (gioi han 4000 buoc, that bai thi bo cuc lai). Goi y tinh tu loi giai. `runs`, `acrossRunOf/downRunOf`, `runSolved`, `isSolved` (moi doan hop le, KHONG can trung loi giai), `errors` (trung / tong da dien vuot / du o sai tong). JSON chi luu `{'s': solution}`, white + clue suy ra.
- Muc: De 5x5 p0.7 3 goi y, Vua 6x6 p0.75 3, Kho 7x7 p0.8 2.
- Man `lib/games/kakuro/presentation/kakuro_screen.dart`: CustomPaint o goi y (duong cheo, tong ngang tren-phai, doc duoi-trai, sang khi doan dang chon, mo khi doan xong), ban phim 1-9 (mo so da dung trong doan), Hoan tac / Xoa / Ghi chu (bitmask) / Goi y (badge), dong ho (dung khi app nen), phim cung 1-9, Backspace, mui ten, N.
- Hieu ung: o chon nay (TweenAnimationBuilder), so PopIn, doan xong chop xanh 650ms, loi Shake + GameFx.error + Sfx.error, thang WinBanner + Sfx.win. Ton trong disableAnimations.
- Khoa luu: `state.kakuro` = {p, lv, v (phang), m (ghi chu phang), t giay, h goi y con}; daily `state.daily.kakuro.<ngay>`. Ky luc: `stats.kakuro` (tong, giay, thap tot) + `stats.kakuro.n<5|6|7>` (theo muc, qua recordScore).
- Bay: de co the nhieu dap an; goi y dien theo loi giai sinh ra nen co the de len so nguoi choi da dien dung theo dap an khac. Xanh lay tu `ColorScheme.fromSeed(Colors.green)` theo do sang theme.
- Test: `test/games/kakuro_engine_test.dart`, `test/games/kakuro_screen_test.dart`.
