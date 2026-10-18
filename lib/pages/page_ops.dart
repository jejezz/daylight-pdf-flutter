import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../convert/conversion_error.dart';
import '../convert/output_paths.dart';

/// 새 PDF에 들어갈 한 쪽: [sourcePath] 문서의 [pageIndex](0부터)쪽을 [quarterTurns]×90° 시계 방향으로 더 돌린 것.
class PageRef {
  const PageRef(this.sourcePath, this.pageIndex, {this.quarterTurns = 0});

  final String sourcePath;
  final int pageIndex;
  final int quarterTurns;
}

/// 합치기·나누기·추출·재배열·회전·삭제. 모두 [build] 하나로 귀결된다: 원하는 쪽을 원하는 순서로 모아 새 PDF를 쓴다.
abstract final class PageOps {
  /// [pages]를 순서대로 담은 PDF를 [outputPath]에 쓴다. 원본 문서는 바꾸지 않는다.
  static Future<void> build(List<PageRef> pages, String outputPath) async {
    if (pages.isEmpty) throw ConversionException(ConversionErrorKind.invalidPageRange, fileName: '');
    final sources = <String, PdfDocument>{};
    PdfDocument? output;
    final Uint8List bytes;
    try {
      for (final path in pages.map((r) => r.sourcePath).toSet()) {
        sources[path] = await _open(path);
      }
      output = await PdfDocument.createNew(sourceName: outputPath);
      output.pages = [
        for (final ref in pages)
          _page(sources[ref.sourcePath]!, ref).rotatedBy(PdfPageRotation.values[ref.quarterTurns & 3]),
      ];
      bytes = await output.encodePdf();
    } finally {
      // 파일 쓰기 전에 모두 닫는다 (출력이 원본과 같은 경로여도, Windows에서도 안전하게).
      output?.dispose();
      for (final doc in sources.values) {
        doc.dispose();
      }
    }
    try {
      final temp = File('$outputPath.tmp');
      temp.writeAsBytesSync(bytes, flush: true);
      temp.renameSync(outputPath);
    } on FileSystemException {
      throw ConversionException(ConversionErrorKind.writeFailed, fileName: p.basename(outputPath));
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

  static Future<int> pageCount(String path) async {
    final doc = await _open(path);
    try {
      return doc.pages.length;
    } finally {
      doc.dispose();
    }
  }

  static PdfPage _page(PdfDocument document, PageRef ref) {
    if (ref.pageIndex < 0 || ref.pageIndex >= document.pages.length) {
      throw ConversionException(ConversionErrorKind.invalidPageRange, fileName: '${ref.pageIndex + 1}');
    }
    return document.pages[ref.pageIndex];
  }

  static Future<PdfDocument> _open(String path) async {
    try {
      return await PdfDocument.openFile(path, passwordProvider: () => null);
    } on PdfPasswordException {
      throw ConversionException(ConversionErrorKind.passwordProtected, fileName: p.basename(path));
    } catch (_) {
      throw ConversionException(ConversionErrorKind.cannotRead, fileName: p.basename(path));
    }
  }
}
