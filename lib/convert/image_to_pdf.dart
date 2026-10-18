import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import 'conversion_error.dart';

/// 이미지 → PDF. 쪽 크기는 이미지 크기(1px = 1pt)이고, 긴 변이 A4 긴 변(842pt)보다 크면 비율을 지켜 줄인다.
/// PNG/JPEG는 원본 그대로 넣고, 나머지는 `image` 패키지가 풀어서 넣는다.
abstract final class ImageToPdf {
  static const extensions = {'png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp', 'tif', 'tiff'};

  static const _maxSide = 842.0;

  static bool supports(String path) => extensions.contains(p.extension(path).replaceFirst('.', '').toLowerCase());

  /// [inputs]를 순서대로 한 쪽씩 담은 PDF를 [outputPath]에 쓴다. 무거운 일은 별도 isolate에서 한다.
  static Future<void> convert(List<String> inputs, String outputPath) =>
      Isolate.run(() => _convert(inputs, outputPath));

  static Future<void> _convert(List<String> inputs, String outputPath) async {
    final document = pw.Document();
    for (final path in inputs) {
      final name = p.basename(path);
      if (!supports(path)) throw ConversionException(ConversionErrorKind.unsupportedFormat, fileName: name);
      final pw.MemoryImage image;
      try {
        image = pw.MemoryImage(File(path).readAsBytesSync());
      } catch (_) {
        throw ConversionException(ConversionErrorKind.cannotRead, fileName: name);
      }
      final width = image.width, height = image.height;
      if (width == null || height == null || width == 0 || height == 0) {
        throw ConversionException(ConversionErrorKind.cannotRead, fileName: name);
      }
      final scale = math.max(width, height) > _maxSide ? _maxSide / math.max(width, height) : 1.0;
      document.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat(width * scale, height * scale),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
        ),
      );
    }
    try {
      File(outputPath).writeAsBytesSync(await document.save(), flush: true);
    } on FileSystemException {
      throw ConversionException(ConversionErrorKind.writeFailed, fileName: p.basename(outputPath));
    }
  }
}
