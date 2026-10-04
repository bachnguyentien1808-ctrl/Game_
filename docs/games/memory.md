# memory (Tim cap)

- Tinh nang: lat the 3D (xoay truc Y), stagger vao man, ghep dung sang+nay+hat, sai lac roi up; kich thuoc 3x4/4x4/5x4/6x6 (cot x hang); 3 bo hinh (icons/shapes/letters, 18 hinh); dong ho, luot, combo, sao 1-3, Nhin truoc (2 lan, 2.2s), tam dung che ban, man ket qua + WinBanner. DAILY: 4x4 bo icons, seed rngFor.
- Cau truc: domain/memory_engine.dart (MemoryGame, MemorySize, MemorySet, FlipResult, starsFor); presentation/memory_screen.dart, memory_card_view.dart, memory_symbols.dart. Test: test/games/memory_test.dart.
- Khoa luu: state 'memory' (daily: daily.memory.<ngay>) gom size,set,symbols,matched,moves,combo,bestCombo,seconds,peeks. Stats: 'memory.<WxH>' (best = luot thap nhat); riengs 4x4 con ghi them vao 'memory' de man chinh hien ky luc.
- Bay: MemorySymbol chi dung khi the lat mat truoc (khong tim thay trong widget test khi up); key the 'memory-card-<gen>-<i>'; sheet can pumpAndSettle trong test.
