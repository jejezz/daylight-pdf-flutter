import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../engine/annotations/annotation_specs.dart';
import '../engine/annotations/pdfium_annotations.dart';

/// 문서에 주석을 쓰고 읽고 지우는 일. 실제로는 PDFium이지만, 상태 로직을 PDFium 없이 시험할 수 있게 틈을 둔다.
abstract interface class AnnotationBackend {
  Future<void> add(PdfDocument document, List<PdfAnnotationSpec> specs);
  Future<List<ReadAnnotation>> read(PdfDocument document, {Set<int>? pages});
  Future<void> remove(PdfDocument document, int pageIndex, int index);
  Future<void> setContents(PdfDocument document, int pageIndex, int index, String text);
}

class PdfiumAnnotationBackend implements AnnotationBackend {
  const PdfiumAnnotationBackend();

  @override
  Future<void> add(PdfDocument document, List<PdfAnnotationSpec> specs) => PdfiumAnnotations.add(document, specs);

  @override
  Future<List<ReadAnnotation>> read(PdfDocument document, {Set<int>? pages}) =>
      PdfiumAnnotations.read(document, pages: pages);

  @override
  Future<void> remove(PdfDocument document, int pageIndex, int index) =>
      PdfiumAnnotations.remove(document, pageIndex, index);

  @override
  Future<void> setContents(PdfDocument document, int pageIndex, int index, String text) =>
      PdfiumAnnotations.setContents(document, pageIndex, index, text);
}

/// 실행 취소가 지울 주석 하나: 그 쪽(0부터)에서 몇 번째인지.
typedef _Placed = ({int page, int index});

/// 마우스로 쪽 위에 그려서 만드는 주석 도구 (형광펜·밑줄은 글자를 고르고 버튼으로 하므로 도구가 아니다).
enum DrawTool { none, note, ink, rectangle, circle }

/// 보기 화면의 주석 상태: 고른 도구와 색, 저장하지 않은 변경 여부, 문서의 주석 목록.
/// 주석은 열린 문서(메모리)에 바로 쓰이고, 파일에는 저장할 때 들어간다.
class AnnotationState extends ChangeNotifier {
  AnnotationState([this._backend = const PdfiumAnnotationBackend()]);

  final AnnotationBackend _backend;
  static const palette = <int>[
    0xFFFFEB3B, // 노랑
    0xFFE53935, // 빨강
    0xFF1E88E5, // 파랑
    0xFF43A047, // 초록
    0xFF8E24AA, // 보라
    0xFFFB8C00, // 주황
  ];

  /// 손글씨·사각형·원의 선 굵기 선택지 (PDF pt): 가늘게, 보통, 굵게.
  static const strokeWidths = <double>[1.5, 3.0, 6.0];

  DrawTool _tool = DrawTool.none;
  int _color = palette.first;
  int _widthIndex = 1;
  bool _fingerDraws = true;
  bool _stylusSeen = false;
  bool _dirty = false;
  bool _busy = false;
  int _revision = 0;
  List<ReadAnnotation> _items = const [];

  /// 실행 취소 기록: 사용자가 한 번 한 일(형광펜 하나가 여러 줄이면 여러 주석)마다 한 칸. 마지막 칸이 먼저 취소된다.
  final _undo = <List<_Placed>>[];

  DrawTool get tool => _tool;
  int get color => _color;
  int get widthIndex => _widthIndex;
  double get strokeWidth => strokeWidths[_widthIndex];

  /// 손가락으로도 그리는지. 꺼져 있으면 펜(스타일러스)만 그리고 손가락은 쪽을 옮기고 확대한다.
  /// 펜 입력이 처음 보이면 저절로 꺼진다 (손바닥이 닿아도 그려지지 않게). 도구 줄에서 다시 켤 수 있다.
  bool get fingerDraws => _fingerDraws;
  bool get dirty => _dirty;
  bool get busy => _busy;
  List<ReadAnnotation> get items => _items;

  /// 되돌릴 일이 있는지.
  bool get canUndo => _undo.isNotEmpty;

  /// 문서 내용이 바뀐 횟수. (쪽을 다시 그리는 일은 `third_party/pdfrx`의 사본이 맡는다.)
  int get revision => _revision;

  /// 그리는 도구가 켜져 있으면 쪽 끌기(스크롤)는 꺼진다.
  bool get drawing => _tool != DrawTool.none;

  /// 같은 도구를 다시 고르면 끈다.
  void toggleTool(DrawTool tool) {
    _tool = _tool == tool ? DrawTool.none : tool;
    notifyListeners();
  }

  void setWidthIndex(int index) {
    _widthIndex = index.clamp(0, strokeWidths.length - 1);
    notifyListeners();
  }

  void setFingerDraws(bool value) {
    _fingerDraws = value;
    notifyListeners();
  }

  /// 펜(스타일러스) 입력을 처음 받았을 때 부른다: 그 뒤로는 손가락이 그리지 않고 쪽을 옮기는 데 쓰인다.
  void noteStylus() {
    if (_stylusSeen) return;
    _stylusSeen = true;
    if (_fingerDraws) {
      _fingerDraws = false;
      notifyListeners();
    }
  }

  void setColor(int color) {
    _color = color;
    notifyListeners();
  }

  void markSaved() {
    _dirty = false;
    notifyListeners();
  }

  /// 주석 목록을 문서에서 다시 읽는다. [pages](0부터)를 주면 그 쪽만 다시 읽고 나머지는 지금 목록을 그대로 쓴다.
  Future<void> refresh(PdfDocument document, {Set<int>? pages}) async {
    if (pages == null) {
      _items = await _backend.read(document);
    } else {
      final fresh = await _backend.read(document, pages: pages);
      _items = [..._items.where((a) => !pages.contains(a.pageIndex)), ...fresh]
        ..sort((a, b) => a.pageIndex != b.pageIndex ? a.pageIndex - b.pageIndex : a.index - b.index);
    }
    notifyListeners();
  }

  Future<void> add(PdfDocument document, List<PdfAnnotationSpec> specs) => _run(() async {
    // PDFium은 새 주석을 그 쪽 주석 목록의 맨 끝에 붙인다. 지금 쪽마다 몇 개 있는지로 새 주석의 번호를 안다.
    final counts = <int, int>{};
    for (final a in _items) {
      counts.update(a.pageIndex, (c) => c + 1, ifAbsent: () => 1);
    }
    final placed = <_Placed>[];
    for (final spec in specs) {
      final n = counts[spec.pageIndex] ?? 0;
      placed.add((page: spec.pageIndex, index: n));
      counts[spec.pageIndex] = n + 1;
    }
    await _backend.add(document, specs);
    _undo.add(placed);
    _dirty = true;
    _revision++;
    await refresh(document, pages: {for (final s in specs) s.pageIndex});
  });

  /// 목록에서 주석 하나를 지운다. 지운 주석은 실행 취소 기록에서 빼고, 같은 쪽의 뒤쪽 번호는 하나씩 당긴다.
  Future<void> remove(PdfDocument document, ReadAnnotation annotation) => _run(() async {
    await _backend.remove(document, annotation.pageIndex, annotation.index);
    for (final step in _undo) {
      step.removeWhere((p) => p.page == annotation.pageIndex && p.index == annotation.index);
      for (var i = 0; i < step.length; i++) {
        final p = step[i];
        if (p.page == annotation.pageIndex && p.index > annotation.index) step[i] = (page: p.page, index: p.index - 1);
      }
    }
    _undo.removeWhere((step) => step.isEmpty);
    _dirty = true;
    _revision++;
    await refresh(document, pages: {annotation.pageIndex});
  });

  /// 메모의 내용을 고친다. 번호가 바뀌지 않으므로 실행 취소 기록은 그대로 두고(고치기 자체는 되돌리지 않는다),
  /// 저장한 파일과 달라지므로 변경됨으로 표시한다.
  Future<void> editNote(PdfDocument document, ReadAnnotation annotation, String text) => _run(() async {
    await _backend.setContents(document, annotation.pageIndex, annotation.index, text);
    _dirty = true;
    await refresh(document, pages: {annotation.pageIndex});
  });

  /// 마지막으로 한 일을 되돌린다 (그때 단 주석을 모두 지운다). 되돌릴 일이 없으면 아무것도 하지 않는다.
  Future<void> undo(PdfDocument document) => _run(() async {
    if (_undo.isEmpty) return;
    final step = _undo.last;
    // 번호가 밀리지 않게 뒤쪽 주석부터 지운다.
    final order = [...step]..sort((a, b) => a.page != b.page ? b.page - a.page : b.index - a.index);
    try {
      for (final p in order) {
        await _backend.remove(document, p.page, p.index);
      }
    } on Object {
      // 중간에 실패하면 기록이 문서와 어긋났을 수 있으니 버리고, 목록은 문서 기준으로 다시 읽는다.
      _undo.clear();
      await refresh(document);
      rethrow;
    }
    _undo.removeLast();
    _dirty = true;
    _revision++;
    await refresh(document, pages: {for (final p in step) p.page});
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
