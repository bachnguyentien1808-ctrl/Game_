# app-shell

## Da xong
TIEN-DO: 1 am thanh: tools/gen_sfx.dart sinh 9 WAV (assets/sfx), audioplayers, SfxEngine (lib/core/audio/sfx_player.dart) gan Sfx.player o main, nuot moi loi plugin. SHA f1ac904
TIEN-DO: 2 cai dat /settings: SettingsController (lib/core/settings/app_settings.dart, khoa settings.*), theme/seed/rung/am/xoa tien do/gioi thieu. SHA f1ac904
TIEN-DO: 3 /daily + /daily/play (lib/features/daily), todayProvider de test ghi de ngay; ProgressStore them lastCelebratedDaily/markDailyCelebrated/totals. SHA f1ac904
TIEN-DO: 4 man chinh moi (hero ngay, choi tiep, loc nhom, luoi the, stagger, Pressable). Nhom game o lib/features/common/shell_widgets.dart (khong sua registry). SHA f1ac904
TIEN-DO: 5 /stats, 6 cach choi (bottom sheet) + gioi thieu 3 trang (co settings.onboarded), 7 CustomTransitionPage fade+slide, tooltip nut icon. SHA f1ac904
Quyet dinh: nhom game de trong features (map id->nhom) thay vi them field GameInfo, tranh dung registry dang nhieu agent sua.

## Tiep theo
8. Icon + splash: tools/gen_icon.dart (goi image) -> assets/icon/*.png; flutter_launcher_icons + flutter_native_splash (dev dep), chay lenh tao file nen tang.
Sau do: docs/games/app-shell.md (may doc), bao cao.
