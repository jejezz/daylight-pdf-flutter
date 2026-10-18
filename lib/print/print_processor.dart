import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdfium_save.dart';
import 'print_gray.dart';
import 'print_layout.dart';
import 'print_options.dart';
import 'print_sheets.dart';
import 'print_stamp.dart';

/// 처리된 쪽 하나: 눈에 보이는 크기와 회전 (겹침을 입힐 때 쓴다).
typedef _PlacedPage = ({double width, double height, double boxWidth, double boxHeight, int rotation});

/// 열린 PDF를 [PrintOptions]대로 가공한 인쇄용 PDF로 만든다. 원본은 바꾸지 않는다.
///
/// 순서: ① 고른 쪽(범위·홀짝·역순)을 새 문서로 모은다 ② 주석을 지우거나 쪽 내용에 굽는다 ③ 쪽마다 용지(또는 모으기 칸)에
/// 배율·여백대로 놓는다 ④ 쪽 번호·워터마크를 입힌다 ⑤ 한 장에 모으거나 소책자로 엮는다 ⑥ 흑백이면 회색 이미지로 바꾼다.
/// 쪽 회전은 그대로 두고, 글자와 그림은 ⑥만 아니면 벡터 그대로 남는다.
abstract final class PrintProcessor {
  static const _link = 2, _widget = 20;

  /// [source]는 `PdfDocument.encodePdf()`로 얻은 바이트(저장 안 한 주석 포함). [currentPage]는 1부터.
  /// [limit]를 주면 고른 쪽 중 앞의 그만큼만 만든다 (미리보기용, 소책자는 쪽 순서가 전체에 달려 있어 무시한다).
  /// [loadFont]는 쪽 번호·워터마크 글꼴 (기본: 앱에 든 SeoulNamsan), [grayDpi]는 흑백 이미지의 해상도.
  static Future<Uint8List> build(
    Uint8List source,
    PrintOptions options, {
    int currentPage = 1,
    int? limit,
    Future<Uint8List> Function() loadFont = loadStampFont,
    int grayDpi = 200,
  }) async {
    final input = await PdfDocument.openData(source, sourceName: 'print-source');
    PdfDocument? assembled;
    PdfDocument? placed;
    try {
      final total = input.pages.length;
      var indices = selectPrintPages(total, options, currentPage: currentPage);
      if (limit != null && !options.booklet) {
        final keep = limit * (options.combines ? options.perSheet : 1);
        if (indices.length > keep) indices = indices.sublist(0, keep);
      }
      // `pages =`는 저장할 때 쪽을 모으므로, 먼저 모은 결과를 다시 열어서 쪽을 손본다.
      assembled = await PdfDocument.createNew(sourceName: 'print');
      assembled.pages = [for (final i in indices) input.pages[i]];
      placed = await PdfDocument.openData(await assembled.encodePdf(), sourceName: 'print-pages');
      if (options.includeAnnotations) await _generateAppearances(placed);
      await _warmUp(placed);

      // 모으기·소책자면 칸 크기를 먼저 정한다 (첫 쪽의 보이는 크기에 칸 모양을 맞춘다)
      final perSheet = options.booklet ? 2 : options.perSheet;
      final plan = perSheet > 1 ? planSheet(perSheet, placed.pages[0].width, placed.pages[0].height, options) : null;
      final pageOptions = plan == null
          ? options
          : options.copyWith(paperWidth: plan.cellWidth, paperHeight: plan.cellHeight, autoOrientation: false);

      final pages = await placed.useNativeDocumentHandle((handle) {
        final pdfium = getPdfium();
        final doc = FPDF_DOCUMENT.fromAddress(handle);
        final out = <_PlacedPage>[];
        for (var i = 0; i < indices.length; i++) {
          final page = pdfium.FPDF_LoadPage(doc, i);
          if (page == ffi.nullptr) {
            out.add((width: 1, height: 1, boxWidth: 1, boxHeight: 1, rotation: 0));
            continue;
          }
          try {
            out.add(_place(pdfium, page, pageOptions));
          } finally {
            pdfium.FPDF_ClosePage(page);
          }
        }
        return out;
      });

      // 쪽 번호·워터마크
      final overlay = await buildStampOverlay(
        pages: [
          for (var i = 0; i < pages.length; i++)
            (
              width: pages[i].width,
              height: pages[i].height,
              number: options.pageNumbers == PrintPageNumbers.none
                  ? null
                  : (options.pageNumberTotal ? '${indices[i] + 1} / $total' : '${indices[i] + 1}'),
              border: plan != null && options.sheetBorder,
            ),
        ],
        options: options,
        fontBytes: await _fontIfNeeded(options, loadFont),
      );
      if (overlay != null) await placed.useNativeDocumentHandle((handle) => _stamp(handle, overlay, pages));

      Uint8List bytes;
      if (plan == null) {
        bytes = await placed.encodePdf();
      } else {
        bytes = await placed.useNativeDocumentHandle((handle) => _combine(handle, pages.length, plan, options));
      }
      if (options.grayscale) bytes = await rasterizeToGray(bytes, dpi: grayDpi);
      return bytes;
    } finally {
      placed?.dispose();
      assembled?.dispose();
      input.dispose();
    }
  }

  /// 문서를 한 번 통째로 저장해 본다 (결과는 버린다). 저장하려면 모든 객체를 읽어야 하므로, 이 뒤로는 메인 스레드의 PDFium 호출이
  /// 아직 읽지 않은 객체를 만나지 않는다. pdfrx는 문서를 필요할 때 읽는 콜백(작업 스레드에만 묶여 있다)으로 열기 때문에,
  /// 읽지 않은 객체를 메인 스레드에서 건드리면 "Cannot invoke native callback from a different isolate"로 앱이 죽는다
  /// (작은 파일은 열 때 다 읽혀서 괜찮고, 큰 매뉴얼에서 `FPDF_ImportNPagesToOne`이 죽었다).
  static Future<void> _warmUp(PdfDocument document) async {
    await document.encodePdf();
  }

  static Future<Uint8List> _fontIfNeeded(PrintOptions options, Future<Uint8List> Function() load) async {
    final needed = options.pageNumbers != PrintPageNumbers.none || options.watermark.trim().isNotEmpty;
    return needed ? load() : Uint8List(0);
  }

  /// 쪽 하나를 처리해 용지(또는 칸)에 놓고, 놓인 모양을 돌려준다.
  static _PlacedPage _place(PDFium pdfium, FPDF_PAGE page, PrintOptions options) {
    // 주석을 지우거나(옵션) 쪽 내용에 굽는다. 굽기는 화면 모양 기준(0)이다: 인쇄 모양(1)은 인쇄 플래그가 없는 주석을 건너뛴다.
    if (!options.includeAnnotations) _removeAnnotations(pdfium, page);
    pdfium.FPDFPage_Flatten(page, 0);

    final box = _pageBox(pdfium, page);
    final rotation = pdfium.FPDFPage_GetRotation(page) * 90;
    final placed = placePage(box, rotation, options);
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
    // 쪽 회전은 그대로 두고 쪽 상자만 용지 크기로.
    pdfium.FPDFPage_SetMediaBox(page, 0, 0, placed.boxWidth, placed.boxHeight);
    pdfium.FPDFPage_SetCropBox(page, 0, 0, placed.boxWidth, placed.boxHeight);
    return (
      width: placed.paperWidth,
      height: placed.paperHeight,
      boxWidth: placed.boxWidth,
      boxHeight: placed.boxHeight,
      rotation: rotation,
    );
  }

  /// 겹침 PDF([overlay])의 i번째 쪽을 문서의 i번째 쪽 위에 폼 객체로 입힌다.
  static void _stamp(int handle, Uint8List overlay, List<_PlacedPage> pages) {
    final pdfium = getPdfium();
    final dest = FPDF_DOCUMENT.fromAddress(handle);
    final buffer = calloc<ffi.Uint8>(overlay.length);
    try {
      buffer.asTypedList(overlay.length).setAll(0, overlay);
      final src = pdfium.FPDF_LoadMemDocument(buffer.cast(), overlay.length, ffi.nullptr);
      if (src == ffi.nullptr) return;
      try {
        for (var i = 0; i < pages.length; i++) {
          final page = pdfium.FPDF_LoadPage(dest, i);
          if (page == ffi.nullptr) continue;
          try {
            final xobject = pdfium.FPDF_NewXObjectFromPage(dest, src, i);
            if (xobject == ffi.nullptr) continue;
            final form = pdfium.FPDF_NewFormObjectFromXObject(xobject);
            if (form != ffi.nullptr) {
              // 겹침은 눈에 보이는 쪽 크기로 만들었으니, 회전된 쪽이면 쪽 좌표로 되돌려 입힌다.
              final m = visibleToUser((
                left: 0,
                bottom: 0,
                right: pages[i].boxWidth,
                top: pages[i].boxHeight,
              ), pages[i].rotation);
              pdfium.FPDFPageObj_Transform(form, m.a, m.b, m.c, m.d, m.e, m.f);
              pdfium.FPDFPage_InsertObject(page, form);
              pdfium.FPDFPage_GenerateContent(page);
            }
            pdfium.FPDF_CloseXObject(xobject);
          } finally {
            pdfium.FPDF_ClosePage(page);
          }
        }
      } finally {
        pdfium.FPDF_CloseDocument(src);
      }
    } finally {
      calloc.free(buffer);
    }
  }

  /// 처리된 [count]쪽을 [plan]대로 한 장에 모은다. 소책자면 접어 철하는 순서로 늘어놓고 빈 쪽을 채운다. 결과 PDF 바이트.
  static Uint8List _combine(int handle, int count, SheetPlan plan, PrintOptions options) {
    final pdfium = getPdfium();
    final src = FPDF_DOCUMENT.fromAddress(handle);
    FPDF_DOCUMENT? ordered;
    FPDF_DOCUMENT? sheets;
    final index = calloc<ffi.Int>(1);
    try {
      var from = src;
      if (options.booklet) {
        // 소책자 순서로 새 문서에 쪽을 늘어놓는다 (빈 쪽은 칸 크기로)
        final order = bookletOrder(count);
        ordered = pdfium.FPDF_CreateNewDocument();
        for (var i = 0; i < order.length; i++) {
          final n = order[i];
          if (n == null) {
            final blank = pdfium.FPDFPage_New(ordered, i, plan.cellWidth, plan.cellHeight);
            pdfium.FPDF_ClosePage(blank);
          } else {
            index.value = n;
            pdfium.FPDF_ImportPagesByIndex(ordered, src, index, 1, i);
          }
        }
        from = ordered;
      }
      // 쪽은 이미 칸 크기에 여백을 두고 놓여 있으니(테두리도 겹침으로 그려져 있다) 칸 수대로 모으기만 한다.
      // 새 문서의 쪽은 열지 않는다: 글꼴이 포함되지 않은 글자가 든 쪽을 메인 스레드에서 열면 PDFium이 글꼴 대체 콜백을 불러 앱이 죽는다.
      sheets = pdfium.FPDF_ImportNPagesToOne(from, plan.sheetWidth, plan.sheetHeight, plan.cols, plan.rows);
      if (sheets == ffi.nullptr) throw StateError('FPDF_ImportNPagesToOne failed');
      return saveDocumentBytes(pdfium, sheets);
    } finally {
      calloc.free(index);
      if (sheets != null && sheets != ffi.nullptr) pdfium.FPDF_CloseDocument(sheets);
      if (ordered != null) pdfium.FPDF_CloseDocument(ordered);
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
