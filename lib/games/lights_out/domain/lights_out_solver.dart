/// Dao trang thai o (r, c) va 4 o lang gieng tren luoi [cells] (tai cho).
void pressCells(List<List<bool>> cells, int r, int c) {
  final n = cells.length;
  for (final (dr, dc) in const [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
    final nr = r + dr;
    final nc = c + dc;
    if (nr >= 0 && nr < n && nc >= 0 && nc < n) {
      cells[nr][nc] = !cells[nr][nc];
    }
  }
}

/// Bo giai Tat den bang khu Gauss tren GF(2), dung cho moi kich thuoc.
/// Khong dung phep dich bit (an toan cho ca web, nhieu hon 32 bit).
abstract final class LightsOutSolver {
  /// Tap o can bam (chi so r * n + c, tang dan) voi so luot IT NHAT de tat het
  /// den; [] neu da tat het; null neu khong giai duoc.
  static List<int>? solve(List<List<bool>> cells) {
    final n = cells.length;
    final v = n * n;
    if (v == 0) return const [];
    // Ma tran mo rong v x (v + 1): cot v la ve phai (den dang sang).
    final m = [
      for (var i = 0; i < v; i++)
        List<int>.filled(v + 1, 0)..[v] = cells[i ~/ n][i % n] ? 1 : 0,
    ];
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        // Bam o (r, c) anh huong toi o i: m[i][j] = 1.
        final j = r * n + c;
        for (final (dr, dc) in const [
          (0, 0),
          (1, 0),
          (-1, 0),
          (0, 1),
          (0, -1),
        ]) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr >= 0 && nr < n && nc >= 0 && nc < n) m[nr * n + nc][j] = 1;
        }
      }
    }

    final pivotRowOfCol = List<int>.filled(v, -1);
    var row = 0;
    for (var col = 0; col < v && row < v; col++) {
      var sel = -1;
      for (var i = row; i < v; i++) {
        if (m[i][col] == 1) {
          sel = i;
          break;
        }
      }
      if (sel < 0) continue;
      final t = m[row];
      m[row] = m[sel];
      m[sel] = t;
      for (var i = 0; i < v; i++) {
        if (i != row && m[i][col] == 1) {
          for (var k = col; k <= v; k++) {
            m[i][k] ^= m[row][k];
          }
        }
      }
      pivotRowOfCol[col] = row;
      row++;
    }
    // Hang 0 = 1 -> vo nghiem.
    for (var i = row; i < v; i++) {
      if (m[i][v] == 1) return null;
    }

    final x0 = List<int>.filled(v, 0);
    final free = <int>[];
    for (var col = 0; col < v; col++) {
      final pr = pivotRowOfCol[col];
      if (pr < 0) {
        free.add(col);
      } else {
        x0[col] = m[pr][v];
      }
    }
    // Co so khong gian nghiem cua he thuan nhat.
    final basis = <List<int>>[
      for (final f in free)
        List<int>.generate(
          v,
          (col) => col == f
              ? 1
              : (pivotRowOfCol[col] >= 0 && m[pivotRowOfCol[col]][f] == 1
                    ? 1
                    : 0),
        ),
    ];
    // Chon to hop co it luot nhat (so chieu nhieu nhat 4 voi kich thuoc <= 6).
    final k = basis.length > 20 ? 0 : basis.length;
    List<int>? best;
    var bestW = v + 1;
    for (var mask = 0; mask < (1 << k); mask++) {
      final x = List<int>.of(x0);
      for (var b = 0; b < k; b++) {
        if ((mask >> b) & 1 == 1) {
          for (var i = 0; i < v; i++) {
            x[i] ^= basis[b][i];
          }
        }
      }
      final w = x.fold<int>(0, (a, e) => a + e);
      if (w < bestW) {
        bestW = w;
        best = x;
      }
    }
    return [
      for (var i = 0; i < v; i++)
        if (best![i] == 1) i,
    ];
  }

  /// So luot toi uu, null neu khong giai duoc.
  static int? minPresses(List<List<bool>> cells) => solve(cells)?.length;

  static bool solvable(List<List<bool>> cells) => solve(cells) != null;
}
