import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'conversion_error.dart';

/// Illustrator `.ai` → PDF. "PDF 호환 파일 만들기"로 저장된 `.ai`는 내용이 PDF라서 PDFium으로 열어 다시 저장한다.
/// 그 옵션이 꺼진 파일(PostScript 계열)은 독점 형식이라 억지로 바꾸지 않고
/// [ConversionErrorKind.notPdfCompatible]로 알린다.
abstract final class AiToPdf {
  static bool supports(String path) => p.extension(path).toLowerCase() == '.ai';

  /// 파일 머리를 보고 PDF 호환 여부를 가른다. PDF 사양은 `%PDF-`가 첫 1024바이트 안에 있으면 허용한다.
  static AiKind sniff(List<int> head) {
    final text = String.fromCharCodes(head.take(1024));
    if (text.contains('%PDF-')) return AiKind.pdfCompatible;
    if (text.startsWith('%!PS-Adobe')) return AiKind.postScript;
    return AiKind.unknown;
  }

  static Future<void> convert(String input, String outputPath) async {
    final name = p.basename(input);
    final List<int> head;
    try {
      final file = File(input).openSync();
      try {
        head = file.readSync(1024);
      } finally {
        file.closeSync();
      }
    } on FileSystemException {
      throw ConversionException(ConversionErrorKind.cannotRead, fileName: name);
    }
    switch (sniff(head)) {
      case AiKind.postScript:
        throw ConversionException(ConversionErrorKind.notPdfCompatible, fileName: name);
      case AiKind.unknown:
        throw ConversionException(ConversionErrorKind.cannotRead, fileName: name);
      case AiKind.pdfCompatible:
        break;
    }

    final PdfDocument document;
    try {
      document = await PdfDocument.openFile(input, passwordProvider: () => null);
    } on PdfPasswordException {
      throw ConversionException(ConversionErrorKind.passwordProtected, fileName: name);
    } catch (_) {
      throw ConversionException(ConversionErrorKind.cannotRead, fileName: name);
    }
    try {
      File(outputPath).writeAsBytesSync(await document.encodePdf(), flush: true);
    } on FileSystemException {
      throw ConversionException(ConversionErrorKind.writeFailed, fileName: p.basename(outputPath));
    } finally {
      document.dispose();
    }
  }
}

enum AiKind { pdfCompatible, postScript, unknown }
