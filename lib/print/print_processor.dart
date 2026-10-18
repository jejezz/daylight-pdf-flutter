import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:pdfrx/pdfrx.dart';

import 'print_layout.dart';
import 'print_options.dart';

/// 열린 PDF를 [PrintOptions]대로 가공한 인쇄용 PDF로 만든다. 원본은 바꾸지 않는다.
///
/// 고른 쪽만 새 문서에 담고(범위·홀짝·역순), 쪽마다 주석을 지우거나 모양을 확정해 두고,
/// 용지 크기의 쪽 안에 배율·여백대로 놓는다 (`FPDFPage_TransFormWithClip`, 주석은 영역만 옮김). 쪽 회전은 그대로 둔다.
/// 글자와 그림은 벡터 그대로 남는다.
abstract final class PrintProcessor {
  static const _link = 2, _widget = 20;

  /// [source]는 `PdfDocument.encodePdf()`로 얻은 바이트(저장 안 한 주석 포함). [currentPage]는 1부터.
  /// [limit]를 주면 고른 쪽 중 앞의 그만큼만 만든다 (미리보기용).
  static Future<Uint8List> build(Uint8List source, PrintOptions options, {int currentPage = 1, int? limit}) async {
    final input = await PdfDocument.openData(source, sourceName: 'print-source');
    PdfDocument? assembled;
    PdfDocument? placed;
    try {
      var indices = selectPrintPages(input.pages.length, options, currentPage: currentPage);
      if (limit != null && indices.length > limit) indices = indices.sublist(0, limit);
      // `pages =`는 저장할 때 쪽을 모으므로, 먼저 모은 결과를 다시 열어서 쪽을 손본다.
      assembled = await PdfDocument.createNew(sourceName: 'print');
      assembled.pages = [for (final i in indices) input.pages[i]];
      placed = await PdfDocument.openData(await assembled.encodePdf(), sourceName: 'print-pages');
      if (options.includeAnnotations) await _generateAppearances(placed);
      await placed.useNativeDocumentHandle((handle) {
        final pdfium = getPdfium();
        final doc = FPDF_DOCUMENT.fromAddress(handle);
        for (var i = 0; i < indices.length; i++) {
          final page = pdfium.FPDF_LoadPage(doc, i);
          if (page == ffi.nullptr) continue;
          try {
            _place(pdfium, page, options);
          } finally {
            pdfium.FPDF_ClosePage(page);
          }
        }
      });
      return await placed.encodePdf();
    } finally {
      placed?.dispose();
      assembled?.dispose();
      input.dispose();
    }
  }

  static void _place(PDFium pdfium, FPDF_PAGE page, PrintOptions options) {
    if (!options.includeAnnotations) _removeAnnotations(pdfium, page);

    final box = _pageBox(pdfium, page);
    final placed = placePage(box, pdfium.FPDFPage_GetRotation(page) * 90, options);
    // 자르기 상자는 새 쪽 상자 좌표: 여백 안쪽 ∩ 원래 쪽이 새 쪽 위에 놓인 모양
    final clip = intersectBoxes(placed.clip, transformBox(placed.matrix, box));

    final matrix = calloc<FS_MATRIX>();
    final clipRect = calloc<FS_RECTF>();
    try {
      matrix.ref
        ..a = placed.matrix.a
        ..b = placed.matrix.b
        ..c = placed.matrix.c
        ..d = placed.matrix.d
        ..e = placed.matrix.e
        ..f = placed.matrix.f;
      clipRect.ref
        ..left = clip.left
        ..bottom = clip.bottom
        ..right = clip.right
        ..top = clip.top;
      pdfium.FPDFPage_TransFormWithClip(page, matrix, clipRect);
    } finally {
      calloc
        ..free(matrix)
        ..free(clipRect);
    }
    // 주석은 자기 영역(Rect)에 모양을 맞춰 그리므로 영역만 옮기면 크기도 따라간다.
    // (`FPDFPage_TransformAnnots`는 쓰지 않는다: 주석 목록을 메인 스레드에서 만들다가 글꼴이 필요하면 앱이 죽는다.)
    _moveAnnotations(pdfium, page, placed.matrix);
    // 쪽 회전은 그대로 두고(주석 모양이 같이 돌도록), 쪽 상자만 용지 크기로.
    pdfium.FPDFPage_SetMediaBox(page, 0, 0, placed.boxWidth, placed.boxHeight);
    pdfium.FPDFPage_SetCropBox(page, 0, 0, placed.boxWidth, placed.boxHeight);
  }

  /// 모든 주석의 영역과 (형광펜·밑줄의) 글자 사각형을 [m]으로 옮긴다. 배율과 이동만 있는 행렬 전용.
  static void _moveAnnotations(PDFium pdfium, FPDF_PAGE page, Matrix6 m) {
    (double, double) map(double x, double y) => (m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f);
    final rect = calloc<FS_RECTF>();
    final quad = calloc<FS_QUADPOINTSF>();
    try {
      for (var i = 0; i < pdfium.FPDFPage_GetAnnotCount(page); i++) {
        final annot = pdfium.FPDFPage_GetAnnot(page, i);
        if (annot == ffi.nullptr) continue;
        try {
          final Object ok = pdfium.FPDFAnnot_GetRect(annot, rect);
          if (ok != false && ok != 0) {
            final (l, b) = map(rect.ref.left, rect.ref.bottom);
            final (r, t) = map(rect.ref.right, rect.ref.top);
            rect.ref
              ..left = l
              ..bottom = b
              ..right = r
              ..top = t;
            pdfium.FPDFAnnot_SetRect(annot, rect);
          }
          final count = pdfium.FPDFAnnot_CountAttachmentPoints(annot);
          for (var q = 0; q < count; q++) {
            final Object got = pdfium.FPDFAnnot_GetAttachmentPoints(annot, q, quad);
            if (got == false || got == 0) continue;
            final p1 = map(quad.ref.x1, quad.ref.y1), p2 = map(quad.ref.x2, quad.ref.y2);
            final p3 = map(quad.ref.x3, quad.ref.y3), p4 = map(quad.ref.x4, quad.ref.y4);
            quad.ref
              ..x1 = p1.$1
              ..y1 = p1.$2
              ..x2 = p2.$1
              ..y2 = p2.$2
              ..x3 = p3.$1
              ..y3 = p3.$2
              ..x4 = p4.$1
              ..y4 = p4.$2;
            pdfium.FPDFAnnot_SetAttachmentPoints(annot, q, quad);
          }
        } finally {
          pdfium.FPDFPage_CloseAnnot(annot);
        }
      }
    } finally {
      calloc
        ..free(rect)
        ..free(quad);
    }
  }

  /// PDFium은 사각형·형광펜·메모 같은 주석의 모양(AP)을 그릴 때 만들어 두므로, 주석이 있는 쪽을 한 번 그려서 모양을 파일에 남긴다.
  /// 그리기는 반드시 pdfrx의 작업 스레드(`PdfPage.render`)로 한다: 모양을 만들다 글꼴이 필요하면 PDFium이 글꼴 대체 콜백을
  /// 부르는데, 그 콜백은 작업 스레드에만 등록돼 있어 메인 스레드에서 `FPDF_RenderPageBitmap`을 부르면 앱이 죽는다.
  static Future<void> _generateAppearances(PdfDocument document) async {
    final withAnnotations = <int>[];
    await document.useNativeDocumentHandle((handle) {
      final pdfium = getPdfium();
      final doc = FPDF_DOCUMENT.fromAddress(handle);
      for (var i = 0; i < document.pages.length; i++) {
        final page = pdfium.FPDF_LoadPage(doc, i);
        if (page == ffi.nullptr) continue;
        try {
          if (pdfium.FPDFPage_GetAnnotCount(page) > 0) withAnnotations.add(i);
        } finally {
          pdfium.FPDF_ClosePage(page);
        }
      }
    });
    for (final i in withAnnotations) {
      final image = await document.pages[i].render(
        fullWidth: 1,
        fullHeight: 1,
        annotationRenderingMode: PdfAnnotationRenderingMode.annotationAndForms,
      );
      image?.dispose();
    }
  }

  /// 링크와 양식 칸을 뺀 모든 주석(메모, 형광펜, 손글씨, 도형…)을 지운다.
  static void _removeAnnotations(PDFium pdfium, FPDF_PAGE page) {
    for (var i = pdfium.FPDFPage_GetAnnotCount(page) - 1; i >= 0; i--) {
      final annot = pdfium.FPDFPage_GetAnnot(page, i);
      if (annot == ffi.nullptr) continue;
      final subtype = pdfium.FPDFAnnot_GetSubtype(annot);
      pdfium.FPDFPage_CloseAnnot(annot);
      if (subtype != _link && subtype != _widget) pdfium.FPDFPage_RemoveAnnot(page, i);
    }
  }

  /// 쪽이 보이는 영역: 자르기 상자(없으면 미디어 상자, 그것도 없으면 Letter).
  static PageBox _pageBox(PDFium pdfium, FPDF_PAGE page) {
    final l = calloc<ffi.Float>(), b = calloc<ffi.Float>(), r = calloc<ffi.Float>(), t = calloc<ffi.Float>();
    try {
      for (final get in [pdfium.FPDFPage_GetCropBox, pdfium.FPDFPage_GetMediaBox]) {
        final Object ok = get(page, l, b, r, t);
        if (ok != false && ok != 0 && r.value > l.value && t.value > b.value) {
          return (left: l.value, bottom: b.value, right: r.value, top: t.value);
        }
      }
      return (left: 0, bottom: 0, right: 612, top: 792);
    } finally {
      calloc
        ..free(l)
        ..free(b)
        ..free(r)
        ..free(t);
    }
  }
}
