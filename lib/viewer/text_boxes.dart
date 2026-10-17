import 'dart:math' as math;

import 'package:pdfrx/pdfrx.dart';

import '../engine/annotations/annotation_specs.dart';

/// 선택한 글자 구간 [start, end)의 글자 상자를 줄마다 하나로 합친다 (형광펜·밑줄이 줄마다 한 덩어리가 되도록).
/// 세로로 절반 넘게 겹치는 글자는 같은 줄로 본다. 크기가 없는 상자(공백 등)는 건너뛴다.
List<PdfBox> lineBoxes(List<PdfRect> charRects, int start, int end) {
  final lines = <({double left, double bottom, double right, double top})>[];
  for (var i = start; i < end && i < charRects.length; i++) {
    final r = charRects[i];
    if (r.right <= r.left || r.top <= r.bottom) continue;
    if (lines.isNotEmpty) {
      final last = lines.last;
      final overlap = math.min(last.top, r.top) - math.max(last.bottom, r.bottom);
      final smaller = math.min(last.top - last.bottom, r.top - r.bottom);
      if (overlap > smaller / 2) {
        lines[lines.length - 1] = (
          left: math.min(last.left, r.left),
          bottom: math.min(last.bottom, r.bottom),
          right: math.max(last.right, r.right),
          top: math.max(last.top, r.top),
        );
        continue;
      }
    }
    lines.add((left: r.left, bottom: r.bottom, right: r.right, top: r.top));
  }
  return lines;
}
