import 'dart:math' as math;

import 'print_options.dart';

/// 쪽 상자(PDF 사용자 공간, 원점 왼쪽 아래).
typedef PageBox = ({double left, double bottom, double right, double top});

/// PDF 변환 행렬: x' = a·x + c·y + e, y' = b·x + d·y + f.
typedef Matrix6 = ({double a, double b, double c, double d, double e, double f});

/// 한 쪽을 용지에 놓는 결과: 용지 크기와, 쪽 내용(회전 전 좌표)을 용지 좌표로 옮기는 행렬.
typedef PlacedPage = ({double paperWidth, double paperHeight, Matrix6 matrix, PageBox clip});

/// 눈에 보이는 쪽 크기(회전 반영).
({double width, double height}) visibleSize(PageBox box, int rotation) {
  final w = box.right - box.left, h = box.top - box.bottom;
  return rotation % 180 == 0 ? (width: w, height: h) : (width: h, height: w);
}

/// [box]에 [rotation](0/90/180/270, 시계 방향) 회전이 걸린 쪽을 [options]의 용지·여백·배율로 놓는다.
/// 회전은 행렬에 녹여, 결과 쪽은 회전 0으로 쓸 수 있다.
PlacedPage placePage(PageBox box, int rotation, PrintOptions options) {
  final rot = ((rotation % 360) + 360) % 360;
  final v = visibleSize(box, rot);
  var pw = options.paperWidth, ph = options.paperHeight;
  if (options.autoOrientation && (v.width > v.height) != (pw > ph)) {
    final t = pw;
    pw = ph;
    ph = t;
  }
  final m = math.min(options.marginPt, math.min(pw, ph) / 2 - 1);
  final innerW = pw - 2 * m, innerH = ph - 2 * m;
  final fit = math.min(innerW / v.width, innerH / v.height);
  final s = switch (options.scale) {
    PrintScale.fit => fit,
    PrintScale.shrink => math.min(1.0, fit),
    PrintScale.actual => 1.0,
  };
  final tx = m + (innerW - v.width * s) / 2, ty = m + (innerH - v.height * s) / 2;

  // 눈에 보이는 좌표 (vx, vy) = α·x + β·y + γ (쪽 왼쪽 아래가 원점)
  final x0 = box.left, y0 = box.bottom, x1 = box.right, y1 = box.top;
  final (ax, bx, gx, ay, by, gy) = switch (rot) {
    90 => (0.0, 1.0, -y0, -1.0, 0.0, x1),
    180 => (-1.0, 0.0, x1, 0.0, -1.0, y1),
    270 => (0.0, -1.0, y1, 1.0, 0.0, -x0),
    _ => (1.0, 0.0, -x0, 0.0, 1.0, -y0),
  };
  return (
    paperWidth: pw,
    paperHeight: ph,
    matrix: (a: s * ax, b: s * ay, c: s * bx, d: s * by, e: s * gx + tx, f: s * gy + ty),
    clip: (left: m, bottom: m, right: pw - m, top: ph - m),
  );
}

/// [box]의 네 꼭짓점을 [m]으로 옮긴 곳을 감싸는 축에 나란한 상자.
/// PDFium의 `FPDFPage_TransFormWithClip`은 자르기 상자를 행렬이 닿기 전 좌표(= 용지 좌표)로 받으므로,
/// 쪽 상자를 용지 위로 옮긴 모양과 [PlacedPage.clip]을 겹쳐 자르기 상자를 만든다.
PageBox transformBox(Matrix6 m, PageBox box) {
  (double, double) map(double x, double y) => (m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f);
  final pts = [map(box.left, box.bottom), map(box.right, box.bottom), map(box.left, box.top), map(box.right, box.top)];
  return (
    left: pts.map((p) => p.$1).reduce(math.min),
    bottom: pts.map((p) => p.$2).reduce(math.min),
    right: pts.map((p) => p.$1).reduce(math.max),
    top: pts.map((p) => p.$2).reduce(math.max),
  );
}

/// 두 상자의 겹치는 부분 (겹치지 않으면 넓이 0).
PageBox intersectBoxes(PageBox a, PageBox b) {
  final l = math.max(a.left, b.left), bt = math.max(a.bottom, b.bottom);
  return (
    left: l,
    bottom: bt,
    right: math.max(l, math.min(a.right, b.right)),
    top: math.max(bt, math.min(a.top, b.top)),
  );
}
