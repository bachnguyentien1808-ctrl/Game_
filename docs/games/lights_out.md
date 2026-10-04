# Tat den (lights_out)

- Che do: Man choi (36 man, 3x3 -> 6x6, sao 3/2/1 theo toi uu / +3, khoa man ke, tien do `state.lights_out.levels`), Ngau nhien (3/4/5/6, ky luc `stats.lights_out.<n>`), Thu thach ngay (5x5, rngFor, dailyBuilder).
- domain: `lights_out_solver.dart` (khu Gauss GF(2), min-weight tren khong gian nghiem, khong dung bitshift cho web), `lights_out_engine.dart` (LightsOut: undo/redo/hint toi da 3/reset, JSON day du), `lights_out_levels.dart` (de man co dinh theo seed = so man, stars()).
- presentation: `lights_out_screen.dart` (menu + vo, PopScope), `lights_out_play.dart` (van choi, hieu ung glow/song lan/thang).
- Khoa luu: `lights_out` (ngau nhien/ngay), `lights_out.level` (man dang choi, co truong level), `lights_out.levels` ({stars:[...]}).
- Stats: id `lights_out` (tong, best = ky luc 5x5 ngau nhien) + `lights_out.<size>` (ky luc ngau nhien theo kich thuoc).
- Bay: `_shown` (hien thi) tach khoi `_game.cells` de song lan tre; huy Timer khi dispose; ban luu cu (chi cells+moves) van doc duoc.
