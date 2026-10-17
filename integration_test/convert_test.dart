// 네이티브 PDFium이 필요해서 `flutter test`가 아니라 실제 앱에서 돈다:
//   flutter test integration_test -d macos
import 'dart:io';

import 'package:daylight_pdf/convert/conversion_error.dart';
import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/convert/pdf_to_images.dart';
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
}
