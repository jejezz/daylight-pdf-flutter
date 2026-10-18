import 'dart:math' as math;

import 'print_options.dart';

/// 쪽 상자(PDF 사용자 공간, 원점 왼쪽 아래).
typedef PageBox = ({double left, double bottom, double right, double top});

/// PDF 변환 행렬: x' = a·x + c·y + e, y' = b·x + d·y + f.
typedef Matrix6 = ({double a, double b, double c, double d, double e, double f});

/// 한 쪽을 용지에 놓는 결과.
/// - [paperWidth]/[paperHeight]: 눈에 보이는 용지 크기 (회전 반영).
/// - [boxWidth]/[boxHeight]: 쪽 상자(회전 전 좌표)로 쓸 크기. 쪽 회전은 그대로 두므로 90°/270°면 가로세로가 바뀐다.
/// - [matrix]: 쪽 내용·주석(회전 전 좌표)을 새 쪽 상자(0,0 기준) 위로 옮기는 배율+이동 행렬. 회전은 들어 있지 않다.
/// - [clip]: 내용을 자를 상자 (새 쪽 상자 좌표).
typedef PlacedPage = ({
  double paperWidth,
  double paperHeight,
  double boxWidth,
  double boxHeight,
  Matrix6 matrix,
  PageBox clip,
});

/// 눈에 보이는 쪽 크기(회전 반영).
({double width, double height}) visibleSize(PageBox box, int rotation) {
  final w = box.right - box.left, h = box.top - box.bottom;
  return rotation % 180 == 0 ? (width: w, height: h) : (width: h, height: w);
}

/// 쪽 상자 [box]에 시계 방향 [rotation]이 걸렸을 때 쪽 좌표 (x, y)가 화면(눈에 보이는 쪽, 왼쪽 아래 원점)에서 놓이는 자리.
({double x, double y}) visiblePoint(PageBox box, int rotation, double x, double y) {
  final u = x - box.left, v = y - box.bottom;
  final w = box.right - box.left, h = box.top - box.bottom;
  return switch (((rotation % 360) + 360) % 360) {
    90 => (x: v, y: w - u),
    180 => (x: w - u, y: h - v),
    270 => (x: h - v, y: u),
    _ => (x: u, y: v),
  };
}

/// [box]에 [rotation](0/90/180/270, 시계 방향) 회전이 걸린 쪽을 [options]의 용지·여백·배율로 놓는다.
/// 쪽 회전은 건드리지 않는다: 회전을 풀어 내용에 녹이면 주석 모양이 따라 돌지 않기 때문이다.
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
  // 눈에 보이는 쪽(왼쪽 아래 원점)에서 용지 위로: 배율 s, 이동 (tx, ty)
  final tx = m + (innerW - v.width * s) / 2, ty = m + (innerH - v.height * s) / 2;

  // 새 쪽 상자는 (0,0)부터. 회전은 그대로이므로, 새 상자의 화면 좌표가 s·(옛 화면 좌표) + (tx, ty)가 되도록 쪽 좌표의 이동량 (e, f)를 푼다.
  final boxW = rot % 180 == 0 ? pw : ph, boxH = rot % 180 == 0 ? ph : pw;
  const newOrigin = 0.0;
  final newBox = (left: newOrigin, bottom: newOrigin, right: boxW, top: boxH);
  final oldAtOrigin = visiblePoint(box, rot, 0, 0); // 쪽 좌표의 선형 부분을 풀기 위한 기준
  final oldAtX = visiblePoint(box, rot, 1, 0), oldAtY = visiblePoint(box, rot, 0, 1);
  // 선형 부분 L (열: x축, y축이 화면에서 가는 방향). 회전만 있으므로 L의 역행렬 = 전치.
  final l11 = oldAtX.x - oldAtOrigin.x, l21 = oldAtX.y - oldAtOrigin.y;
  final l12 = oldAtY.x - oldAtOrigin.x, l22 = oldAtY.y - oldAtOrigin.y;
  // L·e = s·c_old + t − c_new (c: 쪽 좌표 (0,0)의 화면 자리)
  final newAtOrigin = visiblePoint(newBox, rot, 0, 0);
  final rx = s * oldAtOrigin.x + tx - newAtOrigin.x, ry = s * oldAtOrigin.y + ty - newAtOrigin.y;
  final e = l11 * rx + l21 * ry, f = l12 * rx + l22 * ry;
  final userClip = _clipInUserSpace(newBox, rot, m, pw, ph);
  return (
    paperWidth: pw,
    paperHeight: ph,
    boxWidth: boxW,
    boxHeight: boxH,
    matrix: (a: s, b: 0.0, c: 0.0, d: s, e: e, f: f),
    clip: userClip,
  );
}

/// 화면 좌표의 여백 안쪽 상자를 새 쪽 상자의 쪽 좌표 상자로 바꾼다.
PageBox _clipInUserSpace(PageBox newBox, int rot, double m, double pw, double ph) {
  // 화면 상자 [m, pw-m]x[m, ph-m]의 네 꼭짓점에 해당하는 쪽 좌표 상자.
  final lo = (x: m, y: m), hi = (x: pw - m, y: ph - m);
  final pts = <({double x, double y})>[];
  for (final c in [lo, hi, (x: lo.x, y: hi.y), (x: hi.x, y: lo.y)]) {
    pts.add(userFromVisible(newBox, rot, c.x, c.y));
  }
  return (
    left: pts.map((p) => p.x).reduce(math.min),
    bottom: pts.map((p) => p.y).reduce(math.min),
    right: pts.map((p) => p.x).reduce(math.max),
    top: pts.map((p) => p.y).reduce(math.max),
  );
}

/// [visiblePoint]의 역: 화면 좌표 (vx, vy)가 놓이는 쪽 좌표.
({double x, double y}) userFromVisible(PageBox box, int rot, double vx, double vy) {
  final w = box.right - box.left, h = box.top - box.bottom;
  final (u, v) = switch (rot) {
    90 => (w - vy, vx),
    180 => (w - vx, h - vy),
    270 => (vy, h - vx),
    _ => (vx, vy),
  };
  return (x: u + box.left, y: v + box.bottom);
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

/// 눈에 보이는 쪽 좌표(왼쪽 아래 원점)를 쪽 상자 [box]·회전 [rotation]인 쪽의 쪽 좌표로 보내는 행렬.
/// 눈에 보이는 크기로 만든 겹침(쪽 번호·워터마크)을 회전된 쪽에 입힐 때 쓴다.
Matrix6 visibleToUser(PageBox box, int rotation) {
  final rot = ((rotation % 360) + 360) % 360;
  final o = userFromVisible(box, rot, 0, 0);
  final ex = userFromVisible(box, rot, 1, 0), ey = userFromVisible(box, rot, 0, 1);
  return (a: ex.x - o.x, b: ex.y - o.y, c: ey.x - o.x, d: ey.y - o.y, e: o.x, f: o.y);
}
