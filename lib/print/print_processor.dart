import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:pdfrx/pdfrx.dart';

import 'print_layout.dart';
import 'print_options.dart';

/// 열린 PDF를 [PrintOptions]대로 가공한 인쇄용 PDF로 만든다. 원본은 바꾸지 않는다.
///
/// 고른 쪽만 새 문서에 담고(범위·홀짝·역순), 쪽마다 주석을 지우거나 모양을 확정해 두고, 회전을 풀어
/// 용지 크기의 쪽 안에 배율·여백대로 놓는다 (`FPDFPage_TransFormWithClip`, 주석은 `FPDFPage_TransformAnnots`). 글자와 그림은 벡터 그대로 남는다.
abstract final class PrintProcessor {
  static const _link = 2, _widget = 20;
  static const _renderAnnots = 1;

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
    if (options.includeAnnotations) {
      // PDFium은 사각형·형광펜 같은 주석의 모양(AP)을 그릴 때 만들어 두므로, 한 번 그려서 모양을 파일에 남긴다.
      _generateAppearances(pdfium, page);
    } else {
      _removeAnnotations(pdfium, page);
    }

    final box = _pageBox(pdfium, page);
    final placed = placePage(box, pdfium.FPDFPage_GetRotation(page) * 90, options);
    // 자르기 상자는 용지 좌표: 여백 안쪽 ∩ 쪽이 용지 위에 놓인 모양
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
      // 남은 주석(과 양식 칸)도 같은 행렬로 옮긴다. 주석은 자기 영역(Rect)에 모양을 맞춰 그리므로 크기도 따라간다.
      pdfium.FPDFPage_TransformAnnots(
        page,
        placed.matrix.a,
        placed.matrix.b,
        placed.matrix.c,
        placed.matrix.d,
        placed.matrix.e,
        placed.matrix.f,
      );
    } finally {
      calloc
        ..free(matrix)
        ..free(clipRect);
    }
    // 회전은 행렬에 녹았으므로 0으로, 쪽 상자는 용지 크기로.
    pdfium.FPDFPage_SetRotation(page, 0);
    pdfium.FPDFPage_SetMediaBox(page, 0, 0, placed.paperWidth, placed.paperHeight);
    pdfium.FPDFPage_SetCropBox(page, 0, 0, placed.paperWidth, placed.paperHeight);
  }

  static void _generateAppearances(PDFium pdfium, FPDF_PAGE page) {
    final bitmap = pdfium.FPDFBitmap_Create(1, 1, 0);
    if (bitmap == ffi.nullptr) return;
    try {
      pdfium.FPDF_RenderPageBitmap(bitmap, page, 0, 0, 1, 1, 0, _renderAnnots);
    } finally {
      pdfium.FPDFBitmap_Destroy(bitmap);
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
