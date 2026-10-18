import 'dart:math' as math;

import 'print_options.dart';

/// 한 장(시트)에 쪽을 모으는 배치: 가로 [cols] × 세로 [rows] 칸.
class SheetPlan {
  const SheetPlan({
    required this.cols,
    required this.rows,
    required this.sheetWidth,
    required this.sheetHeight,
    required this.cellWidth,
    required this.cellHeight,
    required this.marginPt,
  });

  final int cols, rows;

  /// 용지 크기.
  final double sheetWidth, sheetHeight;

  /// 칸 하나의 크기 (용지를 칸 수로 나눈 것). 쪽은 이 칸 안에 여백을 두고 맞춰 놓인다.
  final double cellWidth, cellHeight;

  /// 칸 안쪽 사방 여백.
  final double marginPt;

  int get perSheet => cols * rows;
}

/// 한 장에 [perSheet]쪽을 모으는 칸 수. 가로로 긴 용지 기준(가로 칸 ≥ 세로 칸)이고, 세로 용지면 가로세로를 바꾼다.
const _grids = <int, (int, int)>{2: (2, 1), 4: (2, 2), 6: (3, 2), 9: (3, 3)};

/// [perSheet]쪽을 한 장에 모으는 배치를 정한다. 첫 쪽 크기 ([pageWidth]×[pageHeight], 보이는 크기)에 칸 모양이 가장 가까운
/// 용지 방향을 고른다 (`autoOrientation`이 꺼져 있으면 옵션의 용지 방향 그대로).
SheetPlan planSheet(int perSheet, double pageWidth, double pageHeight, PrintOptions options) {
  final base = _grids[perSheet];
  if (base == null) throw ArgumentError.value(perSheet, 'perSheet', 'must be 2, 4, 6 or 9');
  final portrait = (options.paperWidth <= options.paperHeight)
      ? (options.paperWidth, options.paperHeight)
      : (options.paperHeight, options.paperWidth);
  final candidates = options.autoOrientation
      ? [(portrait.$2, portrait.$1), portrait] // 가로 용지, 세로 용지
      : [(options.paperWidth, options.paperHeight)];
  final pageAspect = pageWidth / pageHeight;
  SheetPlan? best;
  var bestScore = double.infinity;
  for (final (w, h) in candidates) {
    final (cols, rows) = w >= h ? base : (base.$2, base.$1);
    final cw = w / cols, ch = h / rows;
    final m = math.min(options.marginPt, math.min(cw, ch) / 2 - 1);
    final score = (math.log(((cw - 2 * m) / (ch - 2 * m)) / pageAspect)).abs();
    if (score < bestScore - 1e-9) {
      bestScore = score;
      best = SheetPlan(
        cols: cols,
        rows: rows,
        sheetWidth: w,
        sheetHeight: h,
        cellWidth: cw,
        cellHeight: ch,
        marginPt: m,
      );
    }
  }
  return best!;
}

/// 소책자 쪽 순서: 0부터 센 쪽 번호이고 `null`은 빈 쪽. 결과는 두 쪽씩 한 장(시트)이고 앞면, 뒷면 순서다.
/// 가운데에서 접어 철한다: 시트 i의 앞면은 (끝-2i, 2i+1쪽), 뒷면은 (2i+2쪽, 끝-2i-1쪽) (1부터 센 쪽 번호).
List<int?> bookletOrder(int pageCount) {
  if (pageCount < 1) return const [];
  final n = (pageCount + 3) ~/ 4 * 4;
  int? page(int oneBased) => oneBased <= pageCount ? oneBased - 1 : null;
  final out = <int?>[];
  for (var i = 0; i < n ~/ 4; i++) {
    out
      ..add(page(n - 2 * i))
      ..add(page(2 * i + 1))
      ..add(page(2 * i + 2))
      ..add(page(n - 2 * i - 1));
  }
  return out;
}
