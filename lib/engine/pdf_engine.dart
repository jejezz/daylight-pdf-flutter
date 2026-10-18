import 'dart:io';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// PDF 처리 엔진의 경계. 보기·변환·페이지 조작은 이 인터페이스만 쓰고, 엔진을 바꿀 때는
/// 구현만 교체한다 (CLAUDE.md: 엔진은 인터페이스 뒤에).
abstract interface class PdfEngine {
  Future<PdfDocument> open(String path);

  /// 문서를 [path]에 저장한다. 페이지를 바꾼 문서도 독립된 PDF로 저장된다.
  Future<void> save(PdfDocument document, String path);

  Future<Uint8List> encode(PdfDocument document);
}

/// pdfrx(PDFium) 구현.
class PdfrxEngine implements PdfEngine {
  const PdfrxEngine();

  @override
  Future<PdfDocument> open(String path) => PdfDocument.openFile(path);

  @override
  Future<Uint8List> encode(PdfDocument document) => document.encodePdf();

  @override
  Future<void> save(PdfDocument document, String path) async {
    final bytes = await encode(document);
    await File(path).writeAsBytes(bytes, flush: true);
  }
}
