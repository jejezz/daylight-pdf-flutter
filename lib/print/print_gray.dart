import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

/// 쪽을 [dpi]로 그려 회색 이미지로 바꾼 PDF를 만든다. 컬러 프린터에서도 확실히 흑백으로 찍기 위한 것이다.
/// 글자와 그림은 벡터에서 이미지가 되므로 [dpi]가 낮으면 거칠고 높으면 오래 걸린다.
Future<Uint8List> rasterizeToGray(Uint8List pdfBytes, {int dpi = 200}) async {
  final source = await PdfDocument.openData(pdfBytes, sourceName: 'print-gray');
  try {
    final pages = <({double width, double height, Uint8List jpeg})>[];
    for (final page in source.pages) {
      final pixelWidth = (page.width * dpi / 72).round(), pixelHeight = (page.height * dpi / 72).round();
      final image = await page.render(
        fullWidth: pixelWidth.toDouble(),
        fullHeight: pixelHeight.toDouble(),
        backgroundColor: 0xFFFFFFFF,
        annotationRenderingMode: PdfAnnotationRenderingMode.annotationAndForms,
      );
      if (image == null) continue;
      final bgra = Uint8List.fromList(image.pixels);
      final w = image.width, h = image.height;
      image.dispose();
      // 회색으로 바꾸고 JPEG로 압축하는 일은 무거우니 다른 isolate에서 한다
      final jpeg = await Isolate.run(() => _grayJpeg(bgra, w, h));
      pages.add((width: page.width, height: page.height, jpeg: jpeg));
    }
    final out = pw.Document();
    for (final p in pages) {
      out.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat(p.width, p.height),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(p.jpeg), fit: pw.BoxFit.fill),
        ),
      );
    }
    return await out.save();
  } finally {
    source.dispose();
  }
}

Uint8List _grayJpeg(Uint8List bgra, int width, int height) {
  // 채널이 셋인 이미지에 같은 값을 넣는다 (한 채널 JPEG는 pdf 패키지가 색 공간을 잘못 읽는다)
  final gray = img.Image(width: width, height: height);
  final data = gray.data!.buffer.asUint8List();
  for (var i = 0, j = 0; j < width * height * 3; i += 4, j += 3) {
    // 밝기(ITU-R BT.601)
    final y = (bgra[i + 2] * 299 + bgra[i + 1] * 587 + bgra[i] * 114) ~/ 1000;
    data[j] = data[j + 1] = data[j + 2] = y;
  }
  return img.encodeJpg(gray, quality: 88);
}
