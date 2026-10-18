import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../engine/annotations/annotation_specs.dart';
import 'annotation_state.dart';

/// 그리는 도구가 켜져 있을 때 뷰어 위에 얹어 마우스·손가락·펜 입력을 받는다. 입력은 [PdfViewerController]로 쪽과 PDF 좌표
/// (원점 왼쪽 아래, 쪽 회전 반영)로 바꿔서 [onAdd]에 [PdfAnnotationSpec]으로 넘긴다. 메모는 클릭([onNote])이다.
class DrawLayer extends StatefulWidget {
  const DrawLayer({
    super.key,
    required this.controller,
    required this.state,
    required this.onAdd,
    required this.onNote,
  });

  final PdfViewerController controller;
  final AnnotationState state;
  final void Function(PdfAnnotationSpec spec) onAdd;
  final void Function(int pageIndex, PdfPoint at) onNote;

  @override
  State<DrawLayer> createState() => _DrawLayerState();
}

class _DrawLayerState extends State<DrawLayer> {
  static const _tapSlop = 6.0;

  PdfPage? _page;
  Offset? _downLocal;

  /// 지금 획을 그리고 있는 포인터와 그 종류. 획이 없으면 null.
  int? _strokePointer;
  PointerDeviceKind? _strokeKind;

  /// 손가락 둘 이상이 닿아 쪽을 옮기고 확대하는 중. 이 동안은 새 획을 시작하지 않는다.
  bool _navigating = false;
  final _fingers = <int>{};
  DateTime? _stylusAt;

  bool _isStylus(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.stylus || kind == PointerDeviceKind.invertedStylus;

  /// 펜을 쓴 직후에 닿는 손가락은 손바닥이다.
  bool get _stylusRecent =>
      _stylusAt != null && DateTime.now().difference(_stylusAt!) < const Duration(milliseconds: 1200);

  bool _canDraw(PointerDeviceKind kind) {
    if (_isStylus(kind) || kind == PointerDeviceKind.mouse) return true;
    return widget.state.fingerDraws && !_stylusRecent; // 손가락
  }

  void _cancelStroke() {
    if (_page == null && _strokePointer == null) return;
    setState(() {
      _page = null;
      _downLocal = null;
      _strokePointer = null;
      _strokeKind = null;
      _local.clear();
      _pdf.clear();
    });
  }

  final _local = <Offset>[]; // 화면에 미리 보여 줄 점들
  final _pdf = <PdfPoint>[]; // 같은 쪽 위의 PDF 좌표

  PdfPageHitTestResult? _hit(Offset local) =>
      widget.controller.getPdfPageHitTestResult(local, useDocumentLayoutCoordinates: false);

  void _down(PointerDownEvent e) {
    if (e.kind == PointerDeviceKind.touch) {
      _fingers.add(e.pointer);
      if (_strokeKind == PointerDeviceKind.touch && _strokePointer != null) {
        // 손가락 둘째가 닿았다: 그리던 획은 버리고 두 손가락으로 쪽을 옮기고 확대한다 (뷰어가 그 입력을 받는다)
        _cancelStroke();
        _navigating = true;
        return;
      }
      if (_navigating || _fingers.length > 1) {
        _navigating = true;
        return;
      }
      if (_strokePointer != null) return; // 펜으로 그리는 중에 닿은 손바닥
    } else if (_isStylus(e.kind)) {
      widget.state.noteStylus();
      _stylusAt = DateTime.now();
      _cancelStroke(); // 펜이 닿으면 진행 중이던 손가락 획은 손바닥이었다고 보고 버린다
    }
    if (!_canDraw(e.kind)) return;
    final hit = _hit(e.localPosition);
    if (hit == null) return;
    setState(() {
      _strokePointer = e.pointer;
      _strokeKind = e.kind;
      _page = hit.page;
      _downLocal = e.localPosition;
      _local
        ..clear()
        ..add(e.localPosition);
      _pdf
        ..clear()
        ..add(hit.offset);
    });
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _strokePointer) return;
    if (_isStylus(e.kind)) _stylusAt = DateTime.now();
    final page = _page;
    if (page == null) return;
    final hit = _hit(e.localPosition);
    if (hit == null || hit.page.pageNumber != page.pageNumber) return; // 다른 쪽으로 넘어간 점은 버린다
    setState(() {
      if (widget.state.tool == DrawTool.ink) {
        _local.add(e.localPosition);
        _pdf.add(hit.offset);
      } else {
        // 도형은 시작점과 현재점만 쓴다
        if (_local.length > 1) _local.removeLast();
        if (_pdf.length > 1) _pdf.removeLast();
        _local.add(e.localPosition);
        _pdf.add(hit.offset);
      }
    });
  }

  void _up(PointerUpEvent e) {
    _fingers.remove(e.pointer);
    if (_fingers.isEmpty) _navigating = false;
    if (e.pointer != _strokePointer) return;
    final page = _page;
    if (page == null) return;
    final moved = (e.localPosition - _downLocal!).distance;
    final tool = widget.state.tool;
    final color = widget.state.color;
    final width = widget.state.strokeWidth;
    final points = List.of(_pdf);
    setState(() {
      _page = null;
      _downLocal = null;
      _strokePointer = null;
      _strokeKind = null;
      _local.clear();
      _pdf.clear();
    });
    final pageIndex = page.pageNumber - 1;
    if (tool == DrawTool.note) {
      if (moved <= _tapSlop) widget.onNote(pageIndex, points.first);
      return;
    }
    if (moved <= _tapSlop || points.length < 2) return; // 클릭만으로는 그리지 않는다
    switch (tool) {
      case DrawTool.ink:
        widget.onAdd(
          InkSpec(
            pageIndex: pageIndex,
            color: color,
            strokes: [
              [for (final p in points) (x: p.x, y: p.y)],
            ],
            width: width,
          ),
        );
      case DrawTool.rectangle || DrawTool.circle:
        final a = points.first, b = points.last;
        widget.onAdd(
          ShapeSpec(
            pageIndex: pageIndex,
            color: color,
            kind: tool == DrawTool.circle ? ShapeKind.circle : ShapeKind.square,
            box: (
              left: a.x < b.x ? a.x : b.x,
              bottom: a.y < b.y ? a.y : b.y,
              right: a.x > b.x ? a.x : b.x,
              top: a.y > b.y ? a.y : b.y,
            ),
            width: width,
          ),
        );
      case DrawTool.note || DrawTool.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent, // 휠 스크롤·확대는 아래 뷰어가 계속 받는다
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: (e) {
        _fingers.remove(e.pointer);
        if (_fingers.isEmpty) _navigating = false;
        if (e.pointer == _strokePointer) _cancelStroke();
      },
      child: MouseRegion(
        opaque: false,
        cursor: widget.state.tool == DrawTool.note ? SystemMouseCursors.click : SystemMouseCursors.precise,
        // 그림만 보여 줄 뿐 입력은 가로채지 않는다: 그래야 같은 입력이 아래 뷰어에도 가서 두 손가락 이동·확대와 휠이 된다
        child: IgnorePointer(
          child: CustomPaint(
            painter: _PreviewPainter(
              widget.state.tool,
              Color(widget.state.color),
              List.of(_local),
              // 미리 보이는 선 굵기는 저장될 굵기(pt)에 확대 비율을 곱한 것 (화면 픽셀)
              widget.state.strokeWidth * (widget.controller.isReady ? widget.controller.currentZoom : 1.0),
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.tool, this.color, this.points, this.width);

  final DrawTool tool;
  final Color color;
  final List<Offset> points;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (tool) {
      case DrawTool.ink:
        canvas.drawPath(Path()..addPolygon(points, false), paint);
      case DrawTool.rectangle:
        canvas.drawRect(Rect.fromPoints(points.first, points.last), paint);
      case DrawTool.circle:
        canvas.drawOval(Rect.fromPoints(points.first, points.last), paint);
      case DrawTool.note || DrawTool.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => true;
}
