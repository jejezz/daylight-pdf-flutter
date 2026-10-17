import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../engine/annotations/annotation_specs.dart';
import '../engine/annotations/pdfium_annotations.dart';

/// 마우스로 쪽 위에 그려서 만드는 주석 도구 (형광펜·밑줄은 글자를 고르고 버튼으로 하므로 도구가 아니다).
enum DrawTool { none, note, ink, rectangle, circle }

/// 보기 화면의 주석 상태: 고른 도구와 색, 저장하지 않은 변경 여부, 문서의 주석 목록.
/// 주석은 열린 문서(메모리)에 바로 쓰이고, 파일에는 저장할 때 들어간다.
class AnnotationState extends ChangeNotifier {
  static const palette = <int>[
    0xFFFFEB3B, // 노랑
    0xFFE53935, // 빨강
    0xFF1E88E5, // 파랑
    0xFF43A047, // 초록
    0xFF8E24AA, // 보라
    0xFFFB8C00, // 주황
  ];

  DrawTool _tool = DrawTool.none;
  int _color = palette.first;
  bool _dirty = false;
  bool _busy = false;
  int _revision = 0;
  List<ReadAnnotation> _items = const [];

  DrawTool get tool => _tool;
  int get color => _color;
  bool get dirty => _dirty;
  bool get busy => _busy;
  List<ReadAnnotation> get items => _items;

  /// 문서 내용이 바뀐 횟수. 뷰어는 쪽 크기가 같으면 이미 그린 쪽을 다시 그리지 않으므로, 이 값의 홀짝으로
  /// `PdfViewerParams.annotationRenderingMode`를 바꿔 캐시를 비우게 한다 (viewer_screen.dart).
  int get revision => _revision;

  /// 그리는 도구가 켜져 있으면 쪽 끌기(스크롤)는 꺼진다.
  bool get drawing => _tool != DrawTool.none;

  /// 같은 도구를 다시 고르면 끈다.
  void toggleTool(DrawTool tool) {
    _tool = _tool == tool ? DrawTool.none : tool;
    notifyListeners();
  }

  void setColor(int color) {
    _color = color;
    notifyListeners();
  }

  void markSaved() {
    _dirty = false;
    notifyListeners();
  }

  Future<void> refresh(PdfDocument document) async {
    _items = await PdfiumAnnotations.read(document);
    notifyListeners();
  }

  Future<void> add(PdfDocument document, List<PdfAnnotationSpec> specs) => _run(() async {
    await PdfiumAnnotations.add(document, specs);
    _dirty = true;
    _revision++;
    await refresh(document);
  });

  Future<void> remove(PdfDocument document, ReadAnnotation annotation) => _run(() async {
    await PdfiumAnnotations.remove(document, annotation.pageIndex, annotation.index);
    _dirty = true;
    _revision++;
    await refresh(document);
  });

  /// 한 번에 하나씩만 문서를 건드린다 (PDFium 작업 도중 다음 요청이 끼어들지 않게).
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
