// 네이티브 PDFium이 필요해서 `flutter test`가 아니라 실제 앱에서 돈다:
//   flutter test integration_test -d macos
import 'dart:io';

import 'package:daylight_pdf/convert/ai_to_pdf.dart';
import 'package:daylight_pdf/convert/conversion_error.dart';
import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/convert/pdf_to_images.dart';
import 'package:daylight_pdf/convert/svg_to_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('images → PDF → images round trip keeps page count and size', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_conv_it');
    addTearDown(() => dir.deleteSync(recursive: true));

    final red = img.Image(width: 200, height: 100)..clear(img.ColorRgb8(255, 0, 0));
    final blue = img.Image(width: 100, height: 300)..clear(img.ColorRgb8(0, 0, 255));
    File('${dir.path}/a.png').writeAsBytesSync(img.encodePng(red));
    File('${dir.path}/b.jpg').writeAsBytesSync(img.encodeJpg(blue));
    final pdfPath = '${dir.path}/out.pdf';
    await ImageToPdf.convert(['${dir.path}/a.png', '${dir.path}/b.jpg'], pdfPath);

    final document = await PdfDocument.openFile(pdfPath);
    addTearDown(document.dispose);
    expect(document.pages, hasLength(2));
    expect([document.pages[0].width, document.pages[0].height], [200, 100]);
    expect([document.pages[1].width, document.pages[1].height], [100, 300]);

    final png = await PdfToImages.convert(pdfPath, '${dir.path}/png', dpi: 72);
    expect(png.map((p) => p.split('/').last), ['out-1.png', 'out-2.png']);
    final first = img.decodePng(File(png[0]).readAsBytesSync())!;
    expect([first.width, first.height], [200, 100]);
    final pixel = first.getPixel(100, 50);
    expect([pixel.r, pixel.g, pixel.b], [255, 0, 0]);

    final jpg = await PdfToImages.convert(pdfPath, '${dir.path}/jpg', format: RasterFormat.jpg, dpi: 144);
    final second = img.decodeJpg(File(jpg[1]).readAsBytesSync())!;
    expect([second.width, second.height], [200, 600]);
  });

  testWidgets('PDF → images reports a non-PDF file as unreadable', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_conv_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/fake.pdf').writeAsStringSync('not a pdf');
    await expectLater(
      PdfToImages.convert('${dir.path}/fake.pdf', '${dir.path}/o'),
      throwsA(isA<ConversionException>().having((e) => e.kind, 'kind', ConversionErrorKind.cannotRead)),
    );
  });

  testWidgets('SVG → PDF keeps the vector drawing and the page size', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_conv_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/a.svg').writeAsStringSync(
      '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">'
      '<rect width="200" height="100" fill="#ffffff"/><rect x="0" y="0" width="100" height="100" fill="#ff0000"/></svg>',
    );
    await SvgToPdf.convert('${dir.path}/a.svg', '${dir.path}/a.pdf');

    final document = await PdfDocument.openFile('${dir.path}/a.pdf');
    addTearDown(document.dispose);
    expect(document.pages, hasLength(1));
    expect([document.pages[0].width, document.pages[0].height], [150, 75]);
    final png = await PdfToImages.convert('${dir.path}/a.pdf', '${dir.path}/png', dpi: 72);
    final image = img.decodePng(File(png.single).readAsBytesSync())!;
    final left = image.getPixel(30, 37), right = image.getPixel(120, 37);
    expect([left.r, left.g, left.b], [255, 0, 0]);
    expect([right.r, right.g, right.b], [255, 255, 255]);
  });

  testWidgets('.ai (PDF-compatible) → PDF, and a PostScript .ai is refused', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_conv_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/src.png').writeAsBytesSync(img.encodePng(img.Image(width: 120, height: 80)));
    await ImageToPdf.convert(['${dir.path}/src.png'], '${dir.path}/made.pdf');
    File('${dir.path}/made.pdf').copySync('${dir.path}/logo.ai'); // PDF 호환 .ai는 내용이 PDF다

    await AiToPdf.convert('${dir.path}/logo.ai', '${dir.path}/logo.pdf');
    final document = await PdfDocument.openFile('${dir.path}/logo.pdf');
    addTearDown(document.dispose);
    expect(document.pages, hasLength(1));
    expect([document.pages[0].width, document.pages[0].height], [120, 80]);

    File('${dir.path}/old.ai').writeAsStringSync('%!PS-Adobe-3.0 EPSF-3.0\n%%Creator: Adobe Illustrator\n');
    await expectLater(
      AiToPdf.convert('${dir.path}/old.ai', '${dir.path}/old.pdf'),
      throwsA(isA<ConversionException>().having((e) => e.kind, 'kind', ConversionErrorKind.notPdfCompatible)),
    );
  });
}
