import 'package:pdfrx/pdfrx.dart';

import '../engine/annotations/pdfium_annotations.dart';

/// [pageIndex]쪽의 PDF 좌표 [at]에 놓인 메모(아이콘 영역 안)를 찾는다. 겹쳐 있으면 나중에 단(위에 그려진) 것을 돌려준다.
/// 메모 도구가 켜진 채로 기존 메모 아이콘을 누르면 새 메모를 놓는 대신 그 메모를 열려는 데 쓴다.
ReadAnnotation? noteAt(List<ReadAnnotation> items, int pageIndex, PdfPoint at) {
  for (final a in items.reversed) {
    if (a.subtype != 1 || a.pageIndex != pageIndex) continue;
    final r = a.rect;
    if (at.x >= r.left && at.x <= r.right && at.y >= r.bottom && at.y <= r.top) return a;
  }
  return null;
}
