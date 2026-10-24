import 'dart:ffi' as ffi;
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:pdfrx/pdfrx.dart';

import 'annotation_specs.dart';
import 'svg_appearance.dart';

/// PDFium 주석 API(FFI)로 열린 문서에 주석을 쓰고 읽는다. 문서는 pdfrx의 `useNativeDocumentHandle`로 빌려 쓰므로
/// 저장은 평소처럼 `encodePdf()`면 된다 (PDFium이 같은 메모리 문서를 저장한다).
abstract final class PdfiumAnnotations {
  // PDFium FPDF_ANNOT_* 상수
  static const _flagPrint = 4;
  static const _text = 1;
  static const _square = 5;
  static const _circle = 6;
  static const _highlight = 9;
  static const _underline = 10;
  static const _ink = 15;

  /// [specs]를 문서에 추가한다.
  static Future<void> add(PdfDocument document, List<PdfAnnotationSpec> specs) async {
    if (specs.isEmpty) return;
    final touched = await document.useNativeDocumentHandle((handle) {
      final pdfium = getPdfium();
      final doc = FPDF_DOCUMENT.fromAddress(handle);
      final pages = <int>{};
      for (final spec in specs) {
        final page = pdfium.FPDF_LoadPage(doc, spec.pageIndex);
        if (page == ffi.nullptr) throw StateError('cannot load page ${spec.pageIndex}');
        try {
          _write(pdfium, page, spec);
        } finally {
          pdfium.FPDF_ClosePage(page);
        }
        pages.add(spec.pageIndex + 1);
      }
      return pages.toList();
    });
    await document.reloadPages(pageNumbersToReload: touched);
  }

  /// [pageIndex]쪽의 [annotationIndex]번째 주석(그 쪽 안에서 0부터)을 지운다. 인덱스는 [read]가 쪽마다 돌려주는 순서와 같다.
  static Future<void> remove(PdfDocument document, int pageIndex, int annotationIndex) async {
    await document.useNativeDocumentHandle((handle) {
      final pdfium = getPdfium();
      final page = pdfium.FPDF_LoadPage(FPDF_DOCUMENT.fromAddress(handle), pageIndex);
      if (page == ffi.nullptr) throw StateError('cannot load page $pageIndex');
      try {
        _check(pdfium.FPDFPage_RemoveAnnot(page, annotationIndex), 'RemoveAnnot');
      } finally {
        pdfium.FPDF_ClosePage(page);
      }
    });
    await document.reloadPages(pageNumbersToReload: [pageIndex + 1]);
  }

  /// [pageIndex]쪽의 [annotationIndex]번째 주석의 내용(`Contents`)을 [text]로 바꾼다 (메모 고치기).
  static Future<void> setContents(PdfDocument document, int pageIndex, int annotationIndex, String text) async {
    await document.useNativeDocumentHandle((handle) {
      final pdfium = getPdfium();
      final page = pdfium.FPDF_LoadPage(FPDF_DOCUMENT.fromAddress(handle), pageIndex);
      if (page == ffi.nullptr) throw StateError('cannot load page $pageIndex');
      try {
        final annot = pdfium.FPDFPage_GetAnnot(page, annotationIndex);
        if (annot == ffi.nullptr) throw StateError('no annotation $annotationIndex on page $pageIndex');
        try {
          _setString(pdfium, annot, 'Contents', text);
        } finally {
          pdfium.FPDFPage_CloseAnnot(annot);
        }
      } finally {
        pdfium.FPDF_ClosePage(page);
      }
    });
    await document.reloadPages(pageNumbersToReload: [pageIndex + 1]);
  }

  /// 문서의 주석을 쪽 순서대로 읽는다. [pages](0부터)를 주면 그 쪽만 읽는다 (쪽이 복잡한 큰 문서는 전체 읽기가 몇 초 걸린다).
  ///
  /// 읽기 전에 각 쪽을 pdfrx의 보통 방법(`render`, 작업 스레드)으로 한 번 그려 둔다. 아직 아무도 보지 않은 쪽을
  /// 이 아래에서 메인 스레드 `FPDF_LoadPage`로 처음 읽으면, 그 쪽에 글꼴이 빠져 대체 글꼴이 필요할 때
  /// "Cannot invoke native callback from a different isolate"로 앱이 죽는다(대체 글꼴 콜백은 작업 스레드에만
  /// 등록돼 있다). 작업 스레드가 먼저 그려 두면 PDFium이 그 쪽을 안에서 캐시해, 메인 스레드는 새로 읽지 않고 쓴다.
  /// `annotationRenderingMode: none`이 꼭 필요하다 — 기본값으로 그리면 PDFium이 스티커 메모의 외형(AP)을
  /// 자기 기본 아이콘 크기(20×20pt)로 다시 만들어, 저장한 24×24pt SVG 외형을 덮어써 버린다.
  static Future<List<ReadAnnotation>> read(PdfDocument document, {Set<int>? pages}) async {
    for (var p = 0; p < document.pages.length; p++) {
      if (pages != null && !pages.contains(p)) continue;
      (await document.pages[p].render(
        width: 1,
        height: 1,
        annotationRenderingMode: PdfAnnotationRenderingMode.none,
      ))?.dispose();
    }
    return document.useNativeDocumentHandle((handle) {
      final pdfium = getPdfium();
      final doc = FPDF_DOCUMENT.fromAddress(handle);
      final out = <ReadAnnotation>[];
      for (var p = 0; p < document.pages.length; p++) {
        if (pages != null && !pages.contains(p)) continue;
        final page = pdfium.FPDF_LoadPage(doc, p);
        if (page == ffi.nullptr) continue;
        try {
          final count = pdfium.FPDFPage_GetAnnotCount(page);
          for (var i = 0; i < count; i++) {
            final annot = pdfium.FPDFPage_GetAnnot(page, i);
            if (annot == ffi.nullptr) continue;
            try {
              out.add(
                ReadAnnotation(
                  pageIndex: p,
                  index: i,
                  subtype: pdfium.FPDFAnnot_GetSubtype(annot),
                  contents: _getString(pdfium, annot, 'Contents'),
                  rect: _getRect(pdfium, annot),
                ),
              );
            } finally {
              pdfium.FPDFPage_CloseAnnot(annot);
            }
          }
        } finally {
          pdfium.FPDF_ClosePage(page);
        }
      }
      return out;
    });
  }

  static void _write(PDFium pdfium, FPDF_PAGE page, PdfAnnotationSpec spec) {
    final subtype = switch (spec) {
      HighlightSpec() => _highlight,
      UnderlineSpec() => _underline,
      NoteSpec() => _text,
      InkSpec() => _ink,
      ShapeSpec(kind: ShapeKind.square) => _square,
      ShapeSpec(kind: ShapeKind.circle) => _circle,
    };
    final annot = pdfium.FPDFPage_CreateAnnot(page, subtype);
    if (annot == ffi.nullptr) throw StateError('PDFium cannot create annotation subtype $subtype');
    try {
      // 인쇄 플래그(Print): 다른 뷰어·프린터 드라이버도 이 주석을 찍는다. 없으면 많은 곳에서 화면에만 보이고 인쇄에서 빠진다.
      pdfium.FPDFAnnot_SetFlags(annot, _flagPrint);
      final a = (spec.color >> 24) & 0xFF, r = (spec.color >> 16) & 0xFF, g = (spec.color >> 8) & 0xFF;
      final b = spec.color & 0xFF;
      _check(pdfium.FPDFAnnot_SetColor(annot, FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color, r, g, b, a), 'SetColor');
      switch (spec) {
        case HighlightSpec(:final boxes) || UnderlineSpec(:final boxes):
          _setRect(pdfium, annot, _union(boxes));
          for (final box in boxes) {
            _appendQuad(pdfium, annot, box);
          }
        case NoteSpec(:final x, :final y, :final text, :final iconSvg):
          final box = (left: x, bottom: y, right: x + NoteSpec.iconSize, top: y + NoteSpec.iconSize);
          _setRect(pdfium, annot, box);
          _setString(pdfium, annot, 'Contents', text);
          if (iconSvg != null) {
            // 변환할 수 없는 SVG면 외형을 넣지 않아 뷰어의 기본 메모 아이콘이 쓰인다 (메모는 만들어진다).
            final appearance = svgToAppearance(iconSvg, rect: box, currentColor: spec.color);
            if (appearance != null) _setAppearance(pdfium, annot, appearance);
          }
        case InkSpec(:final strokes, :final width):
          final box = _union([
            for (final s in strokes)
              (
                left: s.map((p) => p.x).reduce(math.min),
                bottom: s.map((p) => p.y).reduce(math.min),
                right: s.map((p) => p.x).reduce(math.max),
                top: s.map((p) => p.y).reduce(math.max),
              ),
          ]);
          _setRect(pdfium, annot, box);
          _check(pdfium.FPDFAnnot_SetBorder(annot, 0, 0, width), 'SetBorder');
          for (final stroke in strokes) {
            final points = calloc<FS_POINTF>(stroke.length);
            try {
              for (var i = 0; i < stroke.length; i++) {
                points[i].x = stroke[i].x;
                points[i].y = stroke[i].y;
              }
              if (pdfium.FPDFAnnot_AddInkStroke(annot, points, stroke.length) < 0) {
                throw StateError('PDFium AddInkStroke failed');
              }
            } finally {
              calloc.free(points);
            }
          }
        case ShapeSpec(:final box, :final width):
          _setRect(pdfium, annot, box);
          _check(pdfium.FPDFAnnot_SetBorder(annot, 0, 0, width), 'SetBorder');
      }
    } finally {
      pdfium.FPDFPage_CloseAnnot(annot);
    }
  }

  static PdfBox _union(List<PdfBox> boxes) => (
    left: boxes.map((b) => b.left).reduce(math.min),
    bottom: boxes.map((b) => b.bottom).reduce(math.min),
    right: boxes.map((b) => b.right).reduce(math.max),
    top: boxes.map((b) => b.top).reduce(math.max),
  );

  static void _setRect(PDFium pdfium, FPDF_ANNOTATION annot, PdfBox box) {
    final rect = calloc<FS_RECTF>();
    try {
      rect.ref
        ..left = box.left
        ..top = box.top
        ..right = box.right
        ..bottom = box.bottom;
      _check(pdfium.FPDFAnnot_SetRect(annot, rect), 'SetRect');
    } finally {
      calloc.free(rect);
    }
  }

  /// 왼쪽 위, 오른쪽 위, 왼쪽 아래, 오른쪽 아래 순 (Acrobat이 쓰는 순서).
  static void _appendQuad(PDFium pdfium, FPDF_ANNOTATION annot, PdfBox box) {
    final quad = calloc<FS_QUADPOINTSF>();
    try {
      quad.ref
        ..x1 = box.left
        ..y1 = box.top
        ..x2 = box.right
        ..y2 = box.top
        ..x3 = box.left
        ..y3 = box.bottom
        ..x4 = box.right
        ..y4 = box.bottom;
      _check(pdfium.FPDFAnnot_AppendAttachmentPoints(annot, quad), 'AppendAttachmentPoints');
    } finally {
      calloc.free(quad);
    }
  }

  static void _setString(PDFium pdfium, FPDF_ANNOTATION annot, String key, String value) {
    final nativeKey = key.toNativeUtf8().cast<ffi.Char>();
    final units = value.codeUnits;
    final wide = calloc<FPDF_WCHAR>(units.length + 1);
    try {
      for (var i = 0; i < units.length; i++) {
        wide[i] = units[i];
      }
      _check(pdfium.FPDFAnnot_SetStringValue(annot, nativeKey, wide), 'SetStringValue');
    } finally {
      calloc.free(wide);
      calloc.free(nativeKey);
    }
  }

  static String _getString(PDFium pdfium, FPDF_ANNOTATION annot, String key) {
    final nativeKey = key.toNativeUtf8().cast<ffi.Char>();
    try {
      final bytes = pdfium.FPDFAnnot_GetStringValue(annot, nativeKey, ffi.nullptr, 0); // UTF-16 바이트 수 (끝 널 포함)
      if (bytes <= 2) return '';
      final buffer = calloc<FPDF_WCHAR>(bytes ~/ 2);
      try {
        pdfium.FPDFAnnot_GetStringValue(annot, nativeKey, buffer, bytes);
        return String.fromCharCodes([for (var i = 0; i < bytes ~/ 2 - 1; i++) buffer[i]]);
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(nativeKey);
    }
  }

  /// 주석의 보통(normal) 외형을 [operators](PDF 그리기 명령)로 정한다. 좌표는 페이지 기준 절대 좌표다
  /// (실험으로 확인: 영역 기준 상대 좌표는 영역이 아니라 페이지 원점에 그려진다).
  static void _setAppearance(PDFium pdfium, FPDF_ANNOTATION annot, String operators) {
    final wide = calloc<FPDF_WCHAR>(operators.length + 1);
    try {
      for (var i = 0; i < operators.length; i++) {
        wide[i] = operators.codeUnitAt(i);
      }
      _check(pdfium.FPDFAnnot_SetAP(annot, 0, wide), 'SetAP'); // 0 = normal
    } finally {
      calloc.free(wide);
    }
  }

  static PdfBox _getRect(PDFium pdfium, FPDF_ANNOTATION annot) {
    final rect = calloc<FS_RECTF>();
    try {
      if (!_ok(pdfium.FPDFAnnot_GetRect(annot, rect))) return (left: 0, bottom: 0, right: 0, top: 0);
      return (left: rect.ref.left, bottom: rect.ref.bottom, right: rect.ref.right, top: rect.ref.top);
    } finally {
      calloc.free(rect);
    }
  }

  static bool _ok(Object value) => value != false && value != 0;

  static void _check(Object ok, String what) {
    if (ok == false || ok == 0) throw StateError('PDFium $what failed');
  }
}

/// [PdfiumAnnotations.read]가 돌려주는 한 주석.
class ReadAnnotation {
  const ReadAnnotation({
    required this.pageIndex,
    required this.index,
    required this.subtype,
    required this.contents,
    this.rect = (left: 0, bottom: 0, right: 0, top: 0),
  });
  final int pageIndex;

  /// 그 쪽 안에서 0부터 센 순서. [PdfiumAnnotations.remove]에 그대로 쓴다.
  final int index;

  /// PDFium `FPDF_ANNOT_*` 값 (1 메모, 5 사각형, 6 원, 9 형광펜, 10 밑줄, 15 손글씨).
  final int subtype;
  final String contents;

  /// 쪽 위의 영역 (PDF 사용자 공간, 원점 왼쪽 아래, pt). 메모 아이콘이 어디에 있는지 알 때 쓴다.
  final PdfBox rect;
}
