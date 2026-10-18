import 'dart:math' as math;

import 'package:xml/xml.dart';

import 'annotation_specs.dart';

/// SVG를 PDF 주석의 외형(appearance) 그리기 명령으로 바꾼다. 메모 아이콘을 저장한 PDF 안에 넣어 다른 뷰어에서도 같은
/// 모양으로 보이게 하려는 것이다 (PDFium의 `FPDFAnnot_SetAP`는 그리기 명령 문자열만 받는다).
///
/// **지원하는 SVG**: 정사각형에 가까운 `viewBox`, `path`·`rect`·`circle`·`ellipse`·`line`·`polyline`·`polygon`, `g`,
/// `transform`(translate·scale·rotate·skew·matrix), 단색 `fill`·`stroke`(`#rgb`/`#rrggbb`/`rgb()`/이름/`currentColor`),
/// `stroke-width`·`linecap`·`linejoin`, `fill-rule`. 경로는 M L H V C S Q T A Z 모두(소문자 상대 좌표 포함).
/// **근사하는 것**: 그라디언트는 색 정지점의 평균색 단색으로, 투명도(`opacity`)는 흰 바탕과 섞은 단색으로 바꾼다
/// (외형 스트림에는 알파를 넣을 자원이 없다). **무시하는 것**: 글자, 이미지, `use`, 클리핑·마스크·필터, 점선.
///
/// 좌표는 [rect](PDF 사용자 공간, 원점 왼쪽 아래)에 비율을 지켜 가운데로 맞춘다. 외형 스트림이 쓰는 좌표는
/// 주석 영역 안이 아니라 **페이지 기준 절대 좌표**이므로 결과도 그렇게 낸다. 그릴 것이 없으면 null.
String? svgToAppearance(String svg, {required PdfBox rect, int currentColor = 0xFF000000}) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(svg);
  } on XmlException {
    return null;
  }
  final root = document.rootElement;
  if (root.name.local != 'svg') return null;

  final view = _viewBox(root);
  if (view == null) return null;
  final boxW = rect.right - rect.left, boxH = rect.top - rect.bottom;
  if (boxW <= 0 || boxH <= 0) return null;
  final scale = math.min(boxW / view.w, boxH / view.h);
  final offsetX = rect.left + (boxW - view.w * scale) / 2;
  final offsetTop = rect.top - (boxH - view.h * scale) / 2;
  // SVG(y 아래로) → PDF(y 위로)
  final base = _Matrix(scale, 0, 0, -scale, offsetX - view.x * scale, offsetTop + view.y * scale);

  final converter = _Converter(gradients: _collectGradients(root), currentColor: _Rgb.fromArgb(currentColor));
  converter.walk(root, _Style.initial, base);
  final out = converter.output.toString().trim();
  return out.isEmpty ? null : out;
}

({double x, double y, double w, double h})? _viewBox(XmlElement root) {
  final raw = root.getAttribute('viewBox');
  if (raw != null) {
    final n = raw.trim().split(RegExp(r'[\s,]+')).map(double.tryParse).toList();
    if (n.length == 4 && n.every((v) => v != null) && n[2]! > 0 && n[3]! > 0) {
      return (x: n[0]!, y: n[1]!, w: n[2]!, h: n[3]!);
    }
  }
  final w = _number(root.getAttribute('width')), h = _number(root.getAttribute('height'));
  if (w != null && h != null && w > 0 && h > 0) return (x: 0, y: 0, w: w, h: h);
  return null;
}

double? _number(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^\s*(-?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)').firstMatch(value);
  return match == null ? null : double.tryParse(match.group(1)!);
}

// ───────────────────────── 색 ─────────────────────────

class _Rgb {
  const _Rgb(this.r, this.g, this.b);
  factory _Rgb.fromArgb(int argb) => _Rgb(((argb >> 16) & 0xFF) / 255, ((argb >> 8) & 0xFF) / 255, (argb & 0xFF) / 255);

  final double r, g, b;

  /// 흰 바탕과 [alpha]만큼 섞는다 (투명도를 단색으로 근사).
  _Rgb overWhite(double alpha) =>
      alpha >= 1 ? this : _Rgb(r * alpha + (1 - alpha), g * alpha + (1 - alpha), b * alpha + (1 - alpha));

  String get ops => '${_n(r)} ${_n(g)} ${_n(b)}';
}

class _Stop {
  const _Stop(this.offset, this.color);
  final double offset;

  /// 흰 바탕과 섞어(정지점 투명도) 단색으로 만든 색.
  final _Rgb color;
}

class _Grad {
  const _Grad({
    required this.stops,
    required this.radial,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.userSpace,
    required this.transform,
  });

  final List<_Stop> stops;
  final bool radial;
  final double x1, y1, x2, y2;

  /// `gradientUnits="userSpaceOnUse"`이면 좌표가 그대로 사용자 공간, 아니면 도형 상자에 대한 비율(0~1).
  final bool userSpace;
  final _Matrix transform;

  /// 그라디언트 위 t(0~1)의 색. 범위 밖은 양 끝 색 (spreadMethod=pad).
  _Rgb colorAt(double t) {
    if (stops.isEmpty) return const _Rgb(0, 0, 0);
    if (t <= stops.first.offset) return stops.first.color;
    if (t >= stops.last.offset) return stops.last.color;
    for (var i = 1; i < stops.length; i++) {
      if (t <= stops[i].offset) {
        final a = stops[i - 1], b = stops[i];
        final span = b.offset - a.offset;
        final f = span <= 0 ? 1.0 : (t - a.offset) / span;
        return _Rgb(
          a.color.r + (b.color.r - a.color.r) * f,
          a.color.g + (b.color.g - a.color.g) * f,
          a.color.b + (b.color.b - a.color.b) * f,
        );
      }
    }
    return stops.last.color;
  }

  /// 단색으로 근사해야 할 때(방사형, 선 색 등)의 평균색.
  _Rgb get average {
    const samples = 9;
    var r = 0.0, g = 0.0, b = 0.0;
    for (var i = 0; i < samples; i++) {
      final c = colorAt(i / (samples - 1));
      r += c.r;
      g += c.g;
      b += c.b;
    }
    return _Rgb(r / samples, g / samples, b / samples);
  }
}

const _named = <String, int>{
  'black': 0x000000,
  'white': 0xFFFFFF,
  'red': 0xFF0000,
  'green': 0x008000,
  'lime': 0x00FF00,
  'blue': 0x0000FF,
  'yellow': 0xFFFF00,
  'orange': 0xFFA500,
  'gray': 0x808080,
  'grey': 0x808080,
  'purple': 0x800080,
  'pink': 0xFFC0CB,
  'brown': 0xA52A2A,
};

/// 단색이면 색, `none`/`transparent`/알 수 없는 값이면 null.
_Rgb? _parseColor(String? raw, _Converter c) {
  if (raw == null) return null;
  final v = raw.trim().toLowerCase();
  if (v.isEmpty || v == 'none' || v == 'transparent') return null;
  if (v == 'currentcolor') return c.currentColor;
  if (v.startsWith('url(')) {
    final id = RegExp(r'url\(\s*#([^)\s]+)').firstMatch(v)?.group(1);
    return id == null ? null : c.gradients[id]?.average;
  }
  if (v.startsWith('#')) {
    var hex = v.substring(1);
    if (hex.length == 3) hex = hex.split('').map((ch) => '$ch$ch').join();
    if (hex.length != 6) return null;
    final n = int.tryParse(hex, radix: 16);
    return n == null ? null : _Rgb.fromArgb(0xFF000000 | n);
  }
  if (v.startsWith('rgb')) {
    final parts = RegExp(r'[-0-9.]+%?').allMatches(v).map((m) => m.group(0)!).toList();
    if (parts.length < 3) return null;
    double channel(String s) => s.endsWith('%') ? (double.parse(s.replaceAll('%', '')) / 100) : double.parse(s) / 255;
    try {
      return _Rgb(channel(parts[0]).clamp(0, 1), channel(parts[1]).clamp(0, 1), channel(parts[2]).clamp(0, 1));
    } on FormatException {
      return null;
    }
  }
  final named = _named[v];
  return named == null ? null : _Rgb.fromArgb(0xFF000000 | named);
}

/// 그라디언트 id → 그라디언트. `href`로 다른 그라디언트의 정지점·속성을 빌려 오는 경우도 따라간다.
Map<String, _Grad> _collectGradients(XmlElement root) {
  final byId = <String, XmlElement>{
    for (final e in root.descendants.whereType<XmlElement>())
      if ((e.name.local == 'linearGradient' || e.name.local == 'radialGradient') && e.getAttribute('id') != null)
        e.getAttribute('id')!: e,
  };
  XmlElement? hrefOf(XmlElement e) {
    final href = (e.getAttribute('href') ?? e.getAttribute('xlink:href'))?.replaceFirst('#', '');
    return href == null ? null : byId[href];
  }

  /// 속성 [name]을 요소에서, 없으면 href로 이어진 요소에서 찾는다 (순환을 막으려고 깊이를 제한).
  String? attr(XmlElement e, String name) {
    XmlElement? cur = e;
    for (var depth = 0; cur != null && depth < 6; depth++) {
      final v = cur.getAttribute(name);
      if (v != null) return v;
      cur = hrefOf(cur);
    }
    return null;
  }

  List<XmlElement> stopsOf(XmlElement e) {
    XmlElement? cur = e;
    for (var depth = 0; cur != null && depth < 6; depth++) {
      final stops = cur.childElements.where((c) => c.name.local == 'stop').toList();
      if (stops.isNotEmpty) return stops;
      cur = hrefOf(cur);
    }
    return const [];
  }

  final tmp = _Converter(gradients: const {}, currentColor: const _Rgb(0, 0, 0));
  double coord(XmlElement e, String name, double fallback) {
    final raw = attr(e, name);
    final n = _number(raw);
    if (raw == null || n == null) return fallback;
    return raw.trim().endsWith('%') ? n / 100 : n;
  }

  final result = <String, _Grad>{};
  for (final entry in byId.entries) {
    final e = entry.value;
    final stops = <_Stop>[];
    var last = 0.0;
    for (final stop in stopsOf(e)) {
      final style = _styleMap(stop.getAttribute('style'));
      var color = _parseColor(style['stop-color'] ?? stop.getAttribute('stop-color') ?? '#000000', tmp);
      if (color == null) continue;
      final opacity = double.tryParse(style['stop-opacity'] ?? stop.getAttribute('stop-opacity') ?? '1') ?? 1;
      color = color.overWhite(opacity.clamp(0, 1).toDouble());
      final rawOffset = stop.getAttribute('offset') ?? '0';
      var offset = _number(rawOffset) ?? 0;
      if (rawOffset.trim().endsWith('%')) offset /= 100;
      offset = math.max(offset.clamp(0, 1).toDouble(), last); // 정지점 위치는 줄어들지 않는다
      last = offset;
      stops.add(_Stop(offset, color));
    }
    if (stops.isEmpty) continue;
    final radial = e.name.local == 'radialGradient';
    result[entry.key] = _Grad(
      stops: stops,
      radial: radial,
      x1: coord(e, 'x1', 0),
      y1: coord(e, 'y1', 0),
      x2: coord(e, 'x2', 1),
      y2: coord(e, 'y2', 0),
      userSpace: attr(e, 'gradientUnits') == 'userSpaceOnUse',
      transform: _Matrix.parse(attr(e, 'gradientTransform')),
    );
  }
  return result;
}

Map<String, String> _styleMap(String? style) {
  if (style == null) return const {};
  return {
    for (final part in style.split(';'))
      if (part.contains(':')) part.split(':').first.trim(): part.substring(part.indexOf(':') + 1).trim(),
  };
}

// ───────────────────────── 변환 행렬 ─────────────────────────

class _Matrix {
  const _Matrix(this.a, this.b, this.c, this.d, this.e, this.f);
  static const identity = _Matrix(1, 0, 0, 1, 0, 0);

  final double a, b, c, d, e, f;

  /// this × other (other를 먼저 적용하고 this를 나중에 적용).
  _Matrix multiply(_Matrix o) => _Matrix(
    a * o.a + c * o.b,
    b * o.a + d * o.b,
    a * o.c + c * o.d,
    b * o.c + d * o.d,
    a * o.e + c * o.f + e,
    b * o.e + d * o.f + f,
  );

  ({double x, double y}) apply(double x, double y) => (x: a * x + c * y + e, y: b * x + d * y + f);

  /// 선 굵기를 곱할 평균 배율.
  double get meanScale => math.sqrt((a * d - b * c).abs());

  static _Matrix parse(String? raw) {
    if (raw == null) return identity;
    var m = identity;
    for (final match in RegExp(r'(\w+)\s*\(([^)]*)\)').allMatches(raw)) {
      final args = match
          .group(2)!
          .trim()
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .map(double.tryParse)
          .toList();
      if (args.any((v) => v == null)) continue;
      final v = args.cast<double>();
      _Matrix? t;
      switch (match.group(1)) {
        case 'translate':
          if (v.isNotEmpty) t = _Matrix(1, 0, 0, 1, v[0], v.length > 1 ? v[1] : 0);
        case 'scale':
          if (v.isNotEmpty) t = _Matrix(v[0], 0, 0, v.length > 1 ? v[1] : v[0], 0, 0);
        case 'rotate':
          if (v.isNotEmpty) {
            final r = v[0] * math.pi / 180;
            final rot = _Matrix(math.cos(r), math.sin(r), -math.sin(r), math.cos(r), 0, 0);
            t = v.length >= 3
                ? _Matrix(1, 0, 0, 1, v[1], v[2]).multiply(rot).multiply(_Matrix(1, 0, 0, 1, -v[1], -v[2]))
                : rot;
          }
        case 'skewX':
          if (v.isNotEmpty) t = _Matrix(1, 0, math.tan(v[0] * math.pi / 180), 1, 0, 0);
        case 'skewY':
          if (v.isNotEmpty) t = _Matrix(1, math.tan(v[0] * math.pi / 180), 0, 1, 0, 0);
        case 'matrix':
          if (v.length == 6) t = _Matrix(v[0], v[1], v[2], v[3], v[4], v[5]);
      }
      if (t != null) m = m.multiply(t);
    }
    return m;
  }
}

// ───────────────────────── 스타일 ─────────────────────────

class _Style {
  const _Style({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
    required this.fillRuleEvenOdd,
    required this.cap,
    required this.join,
    required this.opacity,
    required this.fillOpacity,
    required this.strokeOpacity,
  });

  static const initial = _Style(
    fill: 'black',
    stroke: 'none',
    strokeWidth: 1,
    fillRuleEvenOdd: false,
    cap: 0,
    join: 0,
    opacity: 1,
    fillOpacity: 1,
    strokeOpacity: 1,
  );

  final String fill;
  final String stroke;
  final double strokeWidth;
  final bool fillRuleEvenOdd;
  final int cap;
  final int join;
  final double opacity;
  final double fillOpacity;
  final double strokeOpacity;

  /// 요소의 속성(그리고 `style`)으로 덮어쓴 새 스타일. 속성이 없으면 부모 값을 그대로 물려받는다.
  _Style apply(XmlElement e) {
    final style = _styleMap(e.getAttribute('style'));
    String? prop(String name) => style[name] ?? e.getAttribute(name);
    double? num(String name) => double.tryParse(prop(name) ?? '');
    return _Style(
      fill: prop('fill') ?? fill,
      stroke: prop('stroke') ?? stroke,
      strokeWidth: _number(prop('stroke-width')) ?? strokeWidth,
      fillRuleEvenOdd: prop('fill-rule') == null ? fillRuleEvenOdd : prop('fill-rule') == 'evenodd',
      cap: switch (prop('stroke-linecap')) {
        'round' => 1,
        'square' => 2,
        'butt' => 0,
        _ => cap,
      },
      join: switch (prop('stroke-linejoin')) {
        'round' => 1,
        'bevel' => 2,
        'miter' => 0,
        _ => join,
      },
      // opacity는 자식에게 곱해 내려간다 (SVG 사양과 달리 그룹을 따로 합성하지는 않는 근사)
      opacity: opacity * (num('opacity') ?? 1).clamp(0, 1),
      fillOpacity: num('fill-opacity') ?? fillOpacity,
      strokeOpacity: num('stroke-opacity') ?? strokeOpacity,
    );
  }
}

// ───────────────────────── 요소 → 그리기 명령 ─────────────────────────

const _skipped = {
  'defs',
  'clipPath',
  'mask',
  'filter',
  'title',
  'desc',
  'metadata',
  'style',
  'text',
  'image',
  'use',
  'symbol',
  'linearGradient',
  'radialGradient',
  'pattern',
  'marker',
};

class _Converter {
  _Converter({required this.gradients, required this.currentColor});

  final Map<String, _Grad> gradients;
  final _Rgb currentColor;
  final output = StringBuffer();

  void walk(XmlElement element, _Style parent, _Matrix parentMatrix) {
    final name = element.name.local;
    if (_skipped.contains(name)) return;
    if (element.getAttribute('display') == 'none') return;
    final style = parent.apply(element);
    final matrix = parentMatrix.multiply(_Matrix.parse(element.getAttribute('transform')));

    final path = _shapePath(element, name);
    if (path != null) {
      _paint(path, style, matrix);
    }
    for (final child in element.childElements) {
      walk(child, style, matrix);
    }
  }

  /// `fill="url(#id)"`가 가리키는 그라디언트 (없으면 null).
  _Grad? _gradientOf(String paint) {
    final id = RegExp(r'url\(\s*#([^)\s]+)').firstMatch(paint.trim())?.group(1);
    return id == null ? null : gradients[id];
  }

  void _paint(List<_Seg> segs, _Style style, _Matrix m) {
    if (segs.isEmpty) return;
    final fillAlpha = (style.opacity * style.fillOpacity).clamp(0, 1).toDouble();
    final strokeAlpha = (style.opacity * style.strokeOpacity).clamp(0, 1).toDouble();
    final gradient = _gradientOf(style.fill);
    // 선형 그라디언트는 띠로 그린다. 방사형은 평균색 단색으로 근사한다.
    final stripes = gradient != null && !gradient.radial;
    final fill = stripes ? null : _parseColor(style.fill, this)?.overWhite(fillAlpha);
    final stroke = _parseColor(style.stroke, this)?.overWhite(strokeAlpha);
    if (fill == null && stroke == null && !stripes) return;

    final evenOdd = style.fillRuleEvenOdd ? '*' : '';
    final pathOps = segs.map((s) => s.toOps(m)).join(' ');
    if (stripes) {
      output.write(_gradientFill(segs, gradient, m, pathOps, style.fillRuleEvenOdd, fillAlpha));
    }
    if (fill == null && stroke == null) return;

    final b = StringBuffer('q ');
    if (fill != null) b.write('${fill.ops} rg ');
    if (stroke != null) {
      b.write('${stroke.ops} RG ${_n(style.strokeWidth * m.meanScale)} w ${style.cap} J ${style.join} j ');
    }
    b.write('$pathOps ');
    b.write(
      fill != null && stroke != null
          ? 'B$evenOdd'
          : fill != null
          ? 'f$evenOdd'
          : 'S',
    );
    b.write(' Q\n');
    output.write(b);
  }

  /// 선형 그라디언트 채우기: 도형 모양으로 잘라(`W n`) 그라디언트 방향에 수직인 띠를 색을 바꿔 가며 채운다.
  /// 외형 스트림에는 셰이딩 자원을 넣을 수 없어서 그리기 명령만으로 흉내 낸다. 띠 수는 색 변화가 클수록 늘린다(최대 24).
  String _gradientFill(List<_Seg> segs, _Grad g, _Matrix m, String pathOps, bool evenOdd, double alpha) {
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    void include(double x, double y) {
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }

    for (final s in segs) {
      switch (s) {
        case _Move(:final x, :final y) || _Line(:final x, :final y):
          include(x, y);
        case _Cubic(:final x1, :final y1, :final x2, :final y2, :final x, :final y):
          include(x1, y1);
          include(x2, y2);
          include(x, y);
        case _Close():
          break;
      }
    }
    if (minX.isInfinite) return '';
    final bw = maxX - minX, bh = maxY - minY;

    ({double x, double y}) toUser(double gx, double gy) {
      final p = g.transform.apply(gx, gy);
      return g.userSpace ? p : (x: minX + p.x * bw, y: minY + p.y * bh);
    }

    final u0 = toUser(g.x1, g.y1), u1 = toUser(g.x2, g.y2);
    final p0 = m.apply(u0.x, u0.y), p1 = m.apply(u1.x, u1.y);
    final dx = p1.x - p0.x, dy = p1.y - p0.y;
    final len2 = dx * dx + dy * dy;
    final clip = '$pathOps ${evenOdd ? 'W*' : 'W'} n';
    final corners = [m.apply(minX, minY), m.apply(maxX, minY), m.apply(maxX, maxY), m.apply(minX, maxY)];

    if (len2 < 1e-12) {
      // 시작점과 끝점이 같으면 SVG 사양대로 마지막 색 한 가지로 채운다.
      final c = g.colorAt(1).overWhite(alpha);
      final x0 = corners.map((c) => c.x).reduce(math.min), x1 = corners.map((c) => c.x).reduce(math.max);
      final y0 = corners.map((c) => c.y).reduce(math.min), y1 = corners.map((c) => c.y).reduce(math.max);
      return 'q $clip ${c.ops} rg ${_n(x0)} ${_n(y0)} ${_n(x1 - x0)} ${_n(y1 - y0)} re f Q\n';
    }

    final len = math.sqrt(len2);
    final nx = -dy / len, ny = dx / len;
    double tOf(({double x, double y}) p) => ((p.x - p0.x) * dx + (p.y - p0.y) * dy) / len2;
    final ts = corners.map(tOf).toList();
    final tMin = ts.reduce(math.min), tMax = ts.reduce(math.max);
    // 가로(수직 방향)로 가장 멀리 떨어진 점까지 덮을 폭
    var reach = 0.0;
    for (final c in corners) {
      reach = math.max(reach, ((c.x - p0.x) * nx + (c.y - p0.y) * ny).abs());
    }
    final diag = math.sqrt(
      math.pow(corners.map((c) => c.x).reduce(math.max) - corners.map((c) => c.x).reduce(math.min), 2) +
          math.pow(corners.map((c) => c.y).reduce(math.max) - corners.map((c) => c.y).reduce(math.min), 2),
    );
    final half = reach + diag + 1;

    // 보이는 구간의 색 변화 크기(채널별 최대 변화량)로 띠 수를 정한다. 색이 안 변하면 띠 하나면 된다.
    final lo = [1.0, 1.0, 1.0], hi = [0.0, 0.0, 0.0];
    for (var i = 0; i <= 16; i++) {
      final c = g.colorAt((tMin + (tMax - tMin) * i / 16).clamp(0, 1).toDouble());
      final channels = [c.r, c.g, c.b];
      for (var k = 0; k < 3; k++) {
        lo[k] = math.min(lo[k], channels[k]);
        hi[k] = math.max(hi[k], channels[k]);
      }
    }
    final range = math.max(hi[0] - lo[0], math.max(hi[1] - lo[1], hi[2] - lo[2]));
    final count = (range * 48).ceil().clamp(1, 24);

    final b = StringBuffer('q $clip ');
    final step = (tMax - tMin) / count;
    for (var i = 0; i < count; i++) {
      final t0 = tMin + step * i;
      final t1 = t0 + step * 1.5; // 다음 띠와 살짝 겹쳐 틈이 생기지 않게 한다 (뒤 띠가 위에 덮인다)
      final c = g.colorAt(((t0 + step / 2)).clamp(0, 1).toDouble()).overWhite(alpha);
      final ax = p0.x + dx * t0, ay = p0.y + dy * t0, bx = p0.x + dx * t1, by = p0.y + dy * t1;
      b.write(
        '${c.ops} rg ${_n(ax + nx * half)} ${_n(ay + ny * half)} m ${_n(bx + nx * half)} ${_n(by + ny * half)} l '
        '${_n(bx - nx * half)} ${_n(by - ny * half)} l ${_n(ax - nx * half)} ${_n(ay - ny * half)} l h f ',
      );
    }
    b.write('Q\n');
    return b.toString();
  }

  List<_Seg>? _shapePath(XmlElement e, String name) {
    double v(String attr, [double fallback = 0]) => _number(e.getAttribute(attr)) ?? fallback;
    switch (name) {
      case 'path':
        final d = e.getAttribute('d');
        return d == null ? null : _parsePath(d);
      case 'rect':
        final x = v('x'), y = v('y'), w = v('width'), h = v('height');
        if (w <= 0 || h <= 0) return null;
        var rx = _number(e.getAttribute('rx')), ry = _number(e.getAttribute('ry'));
        rx ??= ry;
        ry ??= rx;
        if (rx == null || rx <= 0) {
          return [_Move(x, y), _Line(x + w, y), _Line(x + w, y + h), _Line(x, y + h), const _Close()];
        }
        rx = math.min(rx, w / 2);
        ry = math.min(ry!, h / 2);
        return _parsePath(
          'M${x + rx},$y H${x + w - rx} A$rx,$ry 0 0 1 ${x + w},${y + ry} V${y + h - ry} '
          'A$rx,$ry 0 0 1 ${x + w - rx},${y + h} H${x + rx} A$rx,$ry 0 0 1 $x,${y + h - ry} '
          'V${y + ry} A$rx,$ry 0 0 1 ${x + rx},$y Z',
        );
      case 'circle':
        final r = v('r');
        return r <= 0 ? null : _ellipse(v('cx'), v('cy'), r, r);
      case 'ellipse':
        final rx = v('rx'), ry = v('ry');
        return rx <= 0 || ry <= 0 ? null : _ellipse(v('cx'), v('cy'), rx, ry);
      case 'line':
        return [_Move(v('x1'), v('y1')), _Line(v('x2'), v('y2'))];
      case 'polyline' || 'polygon':
        final n = (e.getAttribute('points') ?? '')
            .trim()
            .split(RegExp(r'[\s,]+'))
            .where((s) => s.isNotEmpty)
            .map(double.tryParse)
            .toList();
        if (n.length < 4 || n.any((x) => x == null) || n.length.isOdd) return null;
        return [
          _Move(n[0]!, n[1]!),
          for (var i = 2; i < n.length; i += 2) _Line(n[i]!, n[i + 1]!),
          if (name == 'polygon') const _Close(),
        ];
    }
    return null;
  }

  List<_Seg> _ellipse(double cx, double cy, double rx, double ry) =>
      _parsePath('M${cx + rx},$cy A$rx,$ry 0 1 1 ${cx - rx},$cy A$rx,$ry 0 1 1 ${cx + rx},$cy Z');
}

// ───────────────────────── 경로 ─────────────────────────

sealed class _Seg {
  const _Seg();
  String toOps(_Matrix m);
}

class _Move extends _Seg {
  const _Move(this.x, this.y);
  final double x, y;
  @override
  String toOps(_Matrix m) {
    final p = m.apply(x, y);
    return '${_n(p.x)} ${_n(p.y)} m';
  }
}

class _Line extends _Seg {
  const _Line(this.x, this.y);
  final double x, y;
  @override
  String toOps(_Matrix m) {
    final p = m.apply(x, y);
    return '${_n(p.x)} ${_n(p.y)} l';
  }
}

class _Cubic extends _Seg {
  const _Cubic(this.x1, this.y1, this.x2, this.y2, this.x, this.y);
  final double x1, y1, x2, y2, x, y;
  @override
  String toOps(_Matrix m) {
    final a = m.apply(x1, y1), b = m.apply(x2, y2), c = m.apply(x, y);
    return '${_n(a.x)} ${_n(a.y)} ${_n(b.x)} ${_n(b.y)} ${_n(c.x)} ${_n(c.y)} c';
  }
}

class _Close extends _Seg {
  const _Close();
  @override
  String toOps(_Matrix m) => 'h';
}

/// 경로 문자열 `d`를 절대 좌표 선분들로 푼다. 잘못된 명령에서 멈추고 그때까지의 것을 돌려준다 (SVG 사양의 오류 처리).
List<_Seg> _parsePath(String d) {
  final tokens = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  final segs = <_Seg>[];
  var i = 0;
  var cx = 0.0, cy = 0.0; // 현재 점
  var sx = 0.0, sy = 0.0; // 부분 경로 시작점
  var lastCtrlX = 0.0, lastCtrlY = 0.0; // 직전 곡선의 두 번째 제어점 (S/T용)
  String? prev; // 직전 명령 문자
  String? cmd;

  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double? next() {
    if (i >= tokens.length || isCmd(tokens[i])) return null;
    return double.tryParse(tokens[i++]);
  }

  while (i < tokens.length) {
    if (isCmd(tokens[i])) {
      cmd = tokens[i++];
    } else if (cmd == null) {
      break;
    } else if (cmd == 'M') {
      cmd = 'L'; // M 뒤에 좌표가 더 오면 선 긋기
    } else if (cmd == 'm') {
      cmd = 'l';
    }
    final rel = cmd == cmd.toLowerCase();
    final up = cmd.toUpperCase();
    double? a, b, c2, d2, e2, f2, g2;
    switch (up) {
      case 'Z':
        segs.add(const _Close());
        cx = sx;
        cy = sy;
        prev = up;
        continue;
      case 'M' || 'L' || 'T':
        a = next();
        b = next();
        if (a == null || b == null) return segs;
        final x = rel ? cx + a : a, y = rel ? cy + b : b;
        if (up == 'M') {
          segs.add(_Move(x, y));
          sx = x;
          sy = y;
        } else if (up == 'L') {
          segs.add(_Line(x, y));
        } else {
          final qx = (prev == 'Q' || prev == 'T') ? 2 * cx - lastCtrlX : cx;
          final qy = (prev == 'Q' || prev == 'T') ? 2 * cy - lastCtrlY : cy;
          segs.add(_quadToCubic(cx, cy, qx, qy, x, y));
          lastCtrlX = qx;
          lastCtrlY = qy;
        }
        cx = x;
        cy = y;
      case 'H':
        a = next();
        if (a == null) return segs;
        cx = rel ? cx + a : a;
        segs.add(_Line(cx, cy));
      case 'V':
        a = next();
        if (a == null) return segs;
        cy = rel ? cy + a : a;
        segs.add(_Line(cx, cy));
      case 'C':
        a = next();
        b = next();
        c2 = next();
        d2 = next();
        e2 = next();
        f2 = next();
        if ([a, b, c2, d2, e2, f2].contains(null)) return segs;
        final x1 = rel ? cx + a! : a!, y1 = rel ? cy + b! : b!;
        final x2 = rel ? cx + c2! : c2!, y2 = rel ? cy + d2! : d2!;
        final x = rel ? cx + e2! : e2!, y = rel ? cy + f2! : f2!;
        segs.add(_Cubic(x1, y1, x2, y2, x, y));
        lastCtrlX = x2;
        lastCtrlY = y2;
        cx = x;
        cy = y;
      case 'S':
        a = next();
        b = next();
        c2 = next();
        d2 = next();
        if ([a, b, c2, d2].contains(null)) return segs;
        final x1 = (prev == 'C' || prev == 'S') ? 2 * cx - lastCtrlX : cx;
        final y1 = (prev == 'C' || prev == 'S') ? 2 * cy - lastCtrlY : cy;
        final x2 = rel ? cx + a! : a!, y2 = rel ? cy + b! : b!;
        final x = rel ? cx + c2! : c2!, y = rel ? cy + d2! : d2!;
        segs.add(_Cubic(x1, y1, x2, y2, x, y));
        lastCtrlX = x2;
        lastCtrlY = y2;
        cx = x;
        cy = y;
      case 'Q':
        a = next();
        b = next();
        c2 = next();
        d2 = next();
        if ([a, b, c2, d2].contains(null)) return segs;
        final qx = rel ? cx + a! : a!, qy = rel ? cy + b! : b!;
        final x = rel ? cx + c2! : c2!, y = rel ? cy + d2! : d2!;
        segs.add(_quadToCubic(cx, cy, qx, qy, x, y));
        lastCtrlX = qx;
        lastCtrlY = qy;
        cx = x;
        cy = y;
      case 'A':
        a = next();
        b = next();
        c2 = next();
        d2 = next(); // 호 플래그 (0/1)
        e2 = next();
        f2 = next();
        g2 = next();
        if ([a, b, c2, d2, e2, f2, g2].contains(null)) return segs;
        final x = rel ? cx + f2! : f2!, y = rel ? cy + g2! : g2!;
        segs.addAll(_arcToCubics(cx, cy, a!, b!, c2!, d2! != 0, e2! != 0, x, y));
        cx = x;
        cy = y;
      default:
        return segs;
    }
    prev = up;
  }
  return segs;
}

_Cubic _quadToCubic(double x0, double y0, double qx, double qy, double x, double y) =>
    _Cubic(x0 + 2 / 3 * (qx - x0), y0 + 2 / 3 * (qy - y0), x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y), x, y);

/// SVG 호(`A`)를 3차 베지어 곡선들로 바꾼다 (SVG 사양 F.6.5의 중심 매개변수 변환).
List<_Seg> _arcToCubics(
  double x1,
  double y1,
  double rxIn,
  double ryIn,
  double angleDeg,
  bool largeArc,
  bool sweep,
  double x2,
  double y2,
) {
  if (x1 == x2 && y1 == y2) return const [];
  var rx = rxIn.abs(), ry = ryIn.abs();
  if (rx == 0 || ry == 0) return [_Line(x2, y2)];
  final phi = angleDeg * math.pi / 180;
  final cosPhi = math.cos(phi), sinPhi = math.sin(phi);
  final dx = (x1 - x2) / 2, dy = (y1 - y2) / 2;
  final x1p = cosPhi * dx + sinPhi * dy, y1p = -sinPhi * dx + cosPhi * dy;
  final lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lambda > 1) {
    rx *= math.sqrt(lambda);
    ry *= math.sqrt(lambda);
  }
  final numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
  final denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
  final coef = (largeArc == sweep ? -1 : 1) * math.sqrt(math.max(0, numerator / denominator));
  final cxp = coef * (rx * y1p / ry), cyp = coef * -(ry * x1p / rx);
  final cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2;
  final cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2;

  double angle(double ux, double uy, double vx, double vy) {
    final dot = ux * vx + uy * vy;
    final len = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
    var a = math.acos((dot / len).clamp(-1, 1));
    if (ux * vy - uy * vx < 0) a = -a;
    return a;
  }

  final theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
  var delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
  if (!sweep && delta > 0) delta -= 2 * math.pi;
  if (sweep && delta < 0) delta += 2 * math.pi;

  final count = (delta.abs() / (math.pi / 2)).ceil().clamp(1, 16);
  final step = delta / count;
  final t = 4 / 3 * math.tan(step / 4);
  final segs = <_Seg>[];
  var a1 = theta1;
  for (var i = 0; i < count; i++) {
    final a2 = a1 + step;
    final cos1 = math.cos(a1), sin1 = math.sin(a1), cos2 = math.cos(a2), sin2 = math.sin(a2);
    // 단위 원 위의 점과 접선 → 타원으로 늘리고 회전·이동
    ({double x, double y}) map(double ux, double uy) =>
        (x: cosPhi * rx * ux - sinPhi * ry * uy + cx, y: sinPhi * rx * ux + cosPhi * ry * uy + cy);
    final p1 = map(cos1 - t * sin1, sin1 + t * cos1);
    final p2 = map(cos2 + t * sin2, sin2 - t * cos2);
    final p3 = i == count - 1 ? (x: x2, y: y2) : map(cos2, sin2);
    segs.add(_Cubic(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y));
    a1 = a2;
  }
  return segs;
}

/// PDF 숫자: 소수점 셋째 자리까지, 뒤의 0은 뗀다 (지수 표기는 쓰지 않는다).
String _n(double v) {
  final s = v.toStringAsFixed(3);
  if (!s.contains('.')) return s;
  final trimmed = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return trimmed == '-0' ? '0' : trimmed;
}
