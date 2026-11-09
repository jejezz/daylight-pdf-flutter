import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:pdfrx/pdfrx.dart';

import '../convert/conversion_error.dart';
import '../convert/output_paths.dart';
import '../print/pdfium_save.dart';
import '../print/print_layout.dart' show PageBox;
import 'spread_split.dart';

/// 새 PDF에 들어갈 한 쪽: [sourcePath] 문서의 [pageIndex](0부터)쪽을 [quarterTurns]×90° 시계 방향으로 더 돌린 것.
class PageRef {
  const PageRef(this.sourcePath, this.pageIndex, {this.quarterTurns = 0, this.half});

  final String sourcePath;
  final int pageIndex;
  final int quarterTurns;

  /// 펼침면의 보이는 왼쪽/오른쪽 면만 쓰려면 지정한다 (null이면 쪽 전체).
  final SpreadHalf? half;
}

/// 합치기·나누기·추출·재배열·회전·삭제. 모두 [build] 하나로 귀결된다: 원하는 쪽을 원하는 순서로 모아 새 PDF를 쓴다.
abstract final class PageOps {
  /// [pages]를 순서대로 담은 PDF를 [outputPath]에 쓴다. 원본 문서는 바꾸지 않는다.
  static Future<void> build(List<PageRef> pages, String outputPath) async {
    if (pages.isEmpty) throw ConversionException(ConversionErrorKind.invalidPageRange, fileName: '');
    final sources = <String, PdfDocument>{};
    final Uint8List bytes;
    try {
      for (final path in pages.map((r) => r.sourcePath).toSet()) {
        sources[path] = await _open(path);
      }
      for (final ref in pages) {
        _page(sources[ref.sourcePath]!, ref); // 범위를 벗어난 쪽이면 여기서 던진다
      }
      var assembled = await _assemble(pages, sources);
      if (pages.any((r) => r.half != null || r.quarterTurns & 3 != 0)) {
        // 회전·자르기는 모은 결과를 다시 열어 쪽마다 고친 뒤 저장한다.
        // 통째로 메모리에 올려 연다(maxSizeToCacheOnMemory): 그래야 Dart 콜백 없이 PDFium이 직접 읽는다.
        final doc = await PdfDocument.openData(
          assembled,
          sourceName: outputPath,
          maxSizeToCacheOnMemory: assembled.length + 1,
        );
        try {
          await _adjustPages(doc, pages);
          assembled = await doc.encodePdf();
        } finally {
          doc.dispose();
        }
      }
      bytes = assembled;
    } finally {
      // 파일 쓰기 전에 모두 닫는다 (출력이 원본과 같은 경로여도, Windows에서도 안전하게).
      for (final doc in sources.values) {
        doc.dispose();
      }
    }
    final temp = File('$outputPath.tmp');
    try {
      temp.writeAsBytesSync(bytes, flush: true);
    } on FileSystemException {
      throw ConversionException(ConversionErrorKind.writeFailed, fileName: p.basename(outputPath));
    }
    // Windows는 다른 곳이 열어 둔 파일 위로 이름을 바꿀 수 없다. 방금 닫은 문서의 핸들은 pdfrx 작업 스레드가 조금 뒤에 놓으므로
    // 잠깐 기다리며 다시 해 본다. 끝내 안 되면(보기 화면이 그 파일을 열어 둔 경우 등) 임시 파일을 지우고 실패로 알린다.
    for (var attempt = 0;; attempt++) {
      try {
        temp.renameSync(outputPath);
        return;
      } on FileSystemException {
        if (attempt >= 15) {
          try {
            temp.deleteSync();
          } on FileSystemException {
            // 임시 파일이 남아도 다음 저장이 덮어쓴다.
          }
          throw ConversionException(ConversionErrorKind.writeFailed, fileName: p.basename(outputPath));
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// [inputs]를 순서대로 이어 붙인다.
  static Future<void> merge(List<String> inputs, String outputPath) async {
    final refs = <PageRef>[];
    for (final path in inputs) {
      final count = await pageCount(path);
      refs.addAll([for (var i = 0; i < count; i++) PageRef(path, i)]);
    }
    await build(refs, outputPath);
  }

  /// [groups](쪽 번호 1부터)마다 PDF 하나씩 [outputDir]에 만들고 경로를 돌려준다. 이름은 `<원본>-<번호>.pdf`.
  static Future<List<String>> split(String input, String outputDir, List<List<int>> groups) async {
    Directory(outputDir).createSync(recursive: true);
    final base = p.basenameWithoutExtension(input);
    final digits = groups.length.toString().length;
    final outputs = <String>[];
    for (var i = 0; i < groups.length; i++) {
      final path = uniquePath(p.join(outputDir, '$base-${(i + 1).toString().padLeft(digits, '0')}.pdf'));
      await build([for (final n in groups[i]) PageRef(input, n - 1)], path);
      outputs.add(path);
    }
    return outputs;
  }

  /// [input]의 [spreadPages](1부터)를 가운데에서 왼쪽·오른쪽 두 쪽으로 나누고 나머지 쪽은 그대로 둔 PDF를 [outputPath]에 쓴다.
  /// 돌려주는 값은 만들어진 쪽 수.
  static Future<int> splitSpreads(String input, String outputPath, Set<int> spreadPages, {bool rightFirst = false}) async {
    final count = await pageCount(input);
    final plan = planSpreadSplit(count, spreadPages, rightFirst: rightFirst);
    await build([for (final (n, half) in plan) PageRef(input, n - 1, half: half)], outputPath);
    return plan.length;
  }

  static Future<int> pageCount(String path) async {
    final doc = await _open(path, inMemory: false);
    try {
      return doc.pages.length;
    } finally {
      doc.dispose();
    }
  }

  /// 쪽을 PDFium으로 모은다: 같은 원본이 이어지는 구간마다 `FPDF_ImportPagesByIndex`를 **한 번** 부른다.
  /// 쪽을 하나씩 가져오면(pdfrx의 `pages =`) 쪽마다 공유 글꼴·이미지를 통째로 복사해 파일이 몇 배로 커진다.
  /// 한 번에 가져오면 공유 객체는 한 번만 복사되고, 같은 쪽을 여러 번 넣어도(펼침면 나누기) 내용은 하나를 같이 쓴다.
  static Future<Uint8List> _assemble(List<PageRef> pages, Map<String, PdfDocument> sources) async {
    final pdfium = getPdfium();
    final dest = pdfium.FPDF_CreateNewDocument();
    if (dest == ffi.nullptr) throw ConversionException(ConversionErrorKind.cannotRead, fileName: '');
    try {
      var start = 0;
      while (start < pages.length) {
        final path = pages[start].sourcePath;
        var end = start;
        while (end < pages.length && pages[end].sourcePath == path) {
          end++;
        }
        final count = end - start;
        final indices = calloc<ffi.Int>(count);
        try {
          for (var i = 0; i < count; i++) {
            indices[i] = pages[start + i].pageIndex;
          }
          final insertAt = start;
          final Object ok = await sources[path]!.useNativeDocumentHandle(
            (handle) => pdfium.FPDF_ImportPagesByIndex(dest, FPDF_DOCUMENT.fromAddress(handle), indices, count, insertAt),
          );
          if (ok == false || ok == 0) throw ConversionException(ConversionErrorKind.cannotRead, fileName: p.basename(path));
        } finally {
          calloc.free(indices);
        }
        start = end;
      }
      return saveDocumentBytes(pdfium, dest);
    } finally {
      pdfium.FPDF_CloseDocument(dest);
    }
  }

  /// 모은 문서 [document]의 i번째 쪽에 i번째 [PageRef]의 회전을 더하고, 면([PageRef.half])이 있으면 그 절반으로 자른다 (쪽 상자·자르기 상자).
  /// 같은 원본 쪽을 두 번 넣어도 모은 문서에서는 서로 다른 쪽이라 따로 고칠 수 있다.
  static Future<void> _adjustPages(PdfDocument document, List<PageRef> pages) async {
    await document.useNativeDocumentHandle((handle) {
      final pdfium = getPdfium();
      final doc = FPDF_DOCUMENT.fromAddress(handle);
      for (var i = 0; i < pages.length; i++) {
        final ref = pages[i];
        final turns = ref.quarterTurns & 3;
        if (turns == 0 && ref.half == null) continue;
        final page = pdfium.FPDF_LoadPage(doc, i);
        if (page == ffi.nullptr) throw ConversionException(ConversionErrorKind.cannotRead, fileName: '${i + 1}');
        try {
          if (turns != 0) pdfium.FPDFPage_SetRotation(page, (pdfium.FPDFPage_GetRotation(page) + turns) & 3);
          final half = ref.half;
          if (half != null) {
            final box = _visibleBox(pdfium, page);
            final cut = spreadHalfBox(box, pdfium.FPDFPage_GetRotation(page) * 90, half);
            pdfium.FPDFPage_SetMediaBox(page, cut.left, cut.bottom, cut.right, cut.top);
            pdfium.FPDFPage_SetCropBox(page, cut.left, cut.bottom, cut.right, cut.top);
          }
        } finally {
          pdfium.FPDF_ClosePage(page);
        }
      }
    });
  }

  /// 쪽이 보이는 영역: 자르기 상자(없으면 미디어 상자, 그것도 없으면 Letter).
  static PageBox _visibleBox(PDFium pdfium, FPDF_PAGE page) {
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

  static PdfPage _page(PdfDocument document, PageRef ref) {
    if (ref.pageIndex < 0 || ref.pageIndex >= document.pages.length) {
      throw ConversionException(ConversionErrorKind.invalidPageRange, fileName: '${ref.pageIndex + 1}');
    }
    return document.pages[ref.pageIndex];
  }

  static Future<PdfDocument> _open(String path, {bool inMemory = true}) async {
    try {
      if (!inMemory) return await PdfDocument.openFile(path, passwordProvider: () => null);
      // 쪽을 모을 원본은 파일 전체를 메모리로 읽어 연다 (maxSizeToCacheOnMemory를 크기보다 크게 주면 PDFium이 메모리에서 직접 읽는다):
      //  - 파일을 붙들지 않아서, Windows에서 같은 이름으로 덮어쓸 때 이름 바꾸기가 막히지 않는다.
      //  - openData의 기본(1MB 초과)은 Dart 읽기 콜백으로 여는데, 메인 스레드 PDFium이 아직 읽지 않은 객체를 만나면
      //    "Cannot invoke native callback from a different isolate"로 앱이 죽는다.
      final data = await File(path).readAsBytes();
      return await PdfDocument.openData(
        data,
        sourceName: path,
        passwordProvider: () => null,
        maxSizeToCacheOnMemory: data.length + 1,
      );
    } on PdfPasswordException {
      throw ConversionException(ConversionErrorKind.passwordProtected, fileName: p.basename(path));
    } catch (_) {
      throw ConversionException(ConversionErrorKind.cannotRead, fileName: p.basename(path));
    }
  }
}
