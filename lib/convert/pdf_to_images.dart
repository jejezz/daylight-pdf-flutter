import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'conversion_error.dart';
import 'output_paths.dart';

enum RasterFormat {
  png('png'),
  jpg('jpg');

  const RasterFormat(this.extension);
  final String extension;
}

/// PDF → 쪽별 이미지. 결과는 [outputDir] 안의 `<PDF 이름>-<쪽>.<확장자>`이고, 만든 파일 경로를 돌려준다.
abstract final class PdfToImages {
  static const dpiChoices = [72, 150, 300];

  static Future<List<String>> convert(
    String input,
    String outputDir, {
    RasterFormat format = RasterFormat.png,
    int dpi = 150,
  }) async {
    final name = p.basename(input);
    final PdfDocument document;
    try {
      document = await PdfDocument.openFile(input, passwordProvider: () => null);
    } on PdfPasswordException {
      throw ConversionException(ConversionErrorKind.passwordProtected, fileName: name);
    } catch (_) {
      throw ConversionException(ConversionErrorKind.cannotRead, fileName: name);
    }
    final outputs = <String>[];
    try {
      Directory(outputDir).createSync(recursive: true);
      final base = p.basenameWithoutExtension(input);
      final digits = document.pages.length.toString().length;
      for (final page in document.pages) {
        final scale = dpi / 72;
        final rendered = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
          backgroundColor: 0xFFFFFFFF,
        );
        if (rendered == null) throw ConversionException(ConversionErrorKind.cannotRead, fileName: name);
        try {
          final bytes = await Isolate.run(() => _encode(rendered.pixels, rendered.width, rendered.height, format));
          final number = page.pageNumber.toString().padLeft(digits, '0');
          final path = uniquePath(p.join(outputDir, '$base-$number.${format.extension}'));
          File(path).writeAsBytesSync(bytes, flush: true);
          outputs.add(path);
        } on FileSystemException {
          throw ConversionException(ConversionErrorKind.writeFailed, fileName: base);
        } finally {
          rendered.dispose();
        }
      }
    } finally {
      document.dispose();
    }
    return outputs;
  }

  static Uint8List _encode(Uint8List bgra, int width, int height, RasterFormat format) {
    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: bgra.buffer,
      bytesOffset: bgra.offsetInBytes,
      order: img.ChannelOrder.bgra,
      numChannels: 4,
    );
    return switch (format) {
      RasterFormat.png => img.encodePng(image),
      RasterFormat.jpg => img.encodeJpg(image, quality: 92),
    };
  }
}
