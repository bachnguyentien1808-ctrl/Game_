# app-shell (vo ung dung)

## Tinh nang
- Routes (lib/core/router/app_router.dart, moi trang CustomTransitionPage fade+slide, tat khi disableAnimations): `/`, `/settings`, `/stats`, `/daily`, `/daily/play`, `/play/<id>`.
- Man chinh (lib/features/home): gioi thieu 3 trang lan dau (co `settings.onboarded`), hero Thu thach hom nay + chuoi, hang Choi tiep (game co `state.<id>`), loc nhom, luoi the 2 cot (maxCrossAxisExtent 280), dau ? mo bottom sheet Cach choi (GameInfo.howTo, rong thi lay subtitle), stagger vao man.
- Nhom game: map id->GameCategory trong lib/features/common/shell_widgets.dart; game moi mac dinh Logic, them id vao `_categoryOf`.
- Thu thach ngay (lib/features/daily): game = dailyGameFor(today); khong co dailyBuilder -> "Sap co". Vao man goi pruneDaily(keep: hom nay) sau frame dau. Hoan thanh moi (daily.done co hom nay, `daily.celebrated` != hom nay) -> ngon lua + Confetti + Sfx.win mot lan.
- `todayProvider` (DateTime Function()) de test ghi de ngay.
- Cai dat: SettingsController (Notifier) trong lib/core/settings/app_settings.dart; khoa `settings.theme|seed|haptics|sound|onboarded`; ghi vao GameFx.haptics va SfxEngine.enabled ngay khi build/doi.
- Am thanh: tools/gen_sfx.dart -> assets/sfx/<SfxKind.name>.wav (22050 Hz mono). SfxEngine.install() o main gan Sfx.player; 3 AudioPlayer xoay vong moi loai; MissingPluginException -> tat han, moi loi bi nuot. Test khong goi install nen Sfx van no-op.
- Icon/splash: tools/gen_icon.dart -> assets/icon/{icon,foreground,splash}.png; cau hinh flutter_launcher_icons + flutter_native_splash cuoi pubspec.yaml. Doi mau: sua tools/gen_icon.dart + 2 khoi cau hinh, chay 3 lenh trong dau file.

## Bay
- Khong goi ham doi ProgressStore.version trong initState (pruneDaily tang version dong bo khi khong co gi xoa) -> dung addPostFrameCallback.
- flutter_launcher_icons doi `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` trong ios pbxproj thanh `AppIcon`: sua lai `YES` sau moi lan chay.
- Widget test man chinh: dat view 390x844 va pumpAndSettle (stagger chua chay xong thi tap truot).
