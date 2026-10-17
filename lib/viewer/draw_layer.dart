import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../engine/annotations/annotation_specs.dart';
import 'annotation_state.dart';

/// 그리는 도구가 켜져 있을 때 뷰어 위에 얹어 마우스 입력을 받는다. 입력은 [PdfViewerController]로 쪽과 PDF 좌표
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
  final _local = <Offset>[]; // 화면에 미리 보여 줄 점들
  final _pdf = <PdfPoint>[]; // 같은 쪽 위의 PDF 좌표

  PdfPageHitTestResult? _hit(Offset local) =>
      widget.controller.getPdfPageHitTestResult(local, useDocumentLayoutCoordinates: false);

  void _down(PointerDownEvent e) {
    final hit = _hit(e.localPosition);
    if (hit == null) return;
    setState(() {
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
    final page = _page;
    if (page == null) return;
    final moved = (e.localPosition - _downLocal!).distance;
    final tool = widget.state.tool;
    final color = widget.state.color;
    final points = List.of(_pdf);
    setState(() {
      _page = null;
      _downLocal = null;
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
      onPointerCancel: (_) => setState(() {
        _page = null;
        _local.clear();
        _pdf.clear();
      }),
      child: MouseRegion(
        cursor: widget.state.tool == DrawTool.note ? SystemMouseCursors.click : SystemMouseCursors.precise,
        child: CustomPaint(
          painter: _PreviewPainter(widget.state.tool, Color(widget.state.color), List.of(_local)),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.tool, this.color, this.points);

  final DrawTool tool;
  final Color color;
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
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
