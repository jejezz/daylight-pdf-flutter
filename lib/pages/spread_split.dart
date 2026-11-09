import '../print/print_layout.dart' show PageBox;

/// 펼침면(한 쪽에 두 면이 나란히 찍힌 스캔본)에서 화면에 보이는 왼쪽 면 또는 오른쪽 면.
enum SpreadHalf { left, right }

/// [box]는 PDF 좌표(원점 왼쪽 아래)의 쪽 상자이고 [rotation]은 쪽 회전(0/90/180/270, 시계 방향)이다.
/// 사용자가 화면에서 보는 [half] 쪽에 해당하는 상자를 PDF 좌표로 돌려준다 — 가운데에서 둘로 자른 한쪽이다.
/// 회전된 쪽은 보이는 "왼쪽"이 PDF 좌표의 아래/위/오른쪽이 되므로 회전에 맞춰 바꾼다.
PageBox spreadHalfBox(PageBox box, int rotation, SpreadHalf half) {
  final midX = (box.left + box.right) / 2;
  final midY = (box.bottom + box.top) / 2;
  final wantLeft = half == SpreadHalf.left;
  switch (rotation % 360) {
    case 90: // 시계 방향 90°: 보이는 왼쪽 = PDF 아래
      return wantLeft
          ? (left: box.left, bottom: box.bottom, right: box.right, top: midY)
          : (left: box.left, bottom: midY, right: box.right, top: box.top);
    case 180: // 보이는 왼쪽 = PDF 오른쪽
      return wantLeft
          ? (left: midX, bottom: box.bottom, right: box.right, top: box.top)
          : (left: box.left, bottom: box.bottom, right: midX, top: box.top);
    case 270: // 보이는 왼쪽 = PDF 위
      return wantLeft
          ? (left: box.left, bottom: midY, right: box.right, top: box.top)
          : (left: box.left, bottom: box.bottom, right: box.right, top: midY);
    default:
      return wantLeft
          ? (left: box.left, bottom: box.bottom, right: midX, top: box.top)
          : (left: midX, bottom: box.bottom, right: box.right, top: box.top);
  }
}

/// 펼침면 나누기 쪽 목록: [pageCount]쪽 문서에서 [spreadPages](1부터)는 두 면으로 나누고 나머지는 그대로 둔다.
/// [rightFirst]면 오른쪽 면이 먼저 온다(오른쪽에서 왼쪽으로 넘기는 책).
/// 돌려주는 값은 (원본 쪽 번호 1부터, 나눈 면 또는 null) 목록이다.
List<(int, SpreadHalf?)> planSpreadSplit(int pageCount, Set<int> spreadPages, {bool rightFirst = false}) {
  final first = rightFirst ? SpreadHalf.right : SpreadHalf.left;
  final second = rightFirst ? SpreadHalf.left : SpreadHalf.right;
  return [
    for (var n = 1; n <= pageCount; n++)
      if (spreadPages.contains(n)) ...[(n, first), (n, second)] else (n, null),
  ];
}
