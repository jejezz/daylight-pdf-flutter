// 글꼴을 넣지 않은 한글 PDF(굴림 등)가 빈 글자로 나오지 않는지 (third_party/pdfrx_engine/DAYLIGHT_PATCH.md).
//   flutter test integration_test/korean_font_test.dart -d windows
import 'dart:io';

import 'package:daylight_pdf/platform/pdf_fallback_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'raw_pdf.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('non-embedded Korean font (CP949 name) renders and extracts Hangul', (tester) async {
    await tester.runAsync(() async {
      await pdfrxFlutterInitialize();
      await installPdfFallbackFonts();
      final dir = Directory.systemTemp.createTempSync('daylight_pdf_kofont');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/ko.pdf')..writeAsBytesSync(unembeddedKoreanPdf('주문서 한글'));

      final doc = await PdfDocument.openFile(file.path);
      addTearDown(doc.dispose);
      final page = doc.pages.first;
      expect((await page.loadText())?.fullText, contains('주문서'));

      final image = await page.render(fullWidth: 800.0, fullHeight: 240.0);
      addTearDown(image!.dispose);
      var dark = 0;
      final px = image.pixels;
      for (var i = 0; i < px.length; i += 4) {
        if (px[i] < 100 && px[i + 1] < 100 && px[i + 2] < 100) dark++;
      }
      // 글꼴을 못 찾으면 글자가 비어 어두운 픽셀이 거의 없다.
      expect(dark, greaterThan(1500));
    });
  });
}
