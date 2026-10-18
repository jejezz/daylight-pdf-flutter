import 'dart:typed_data';

import 'package:daylight_pdf/print/print_options.dart';
import 'package:daylight_pdf/print/print_processor.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

// 객체가 많은 큰 PDF에서 모아 찍기가 앱을 죽이지 않는지 확인한다:
//   flutter test integration_test/print_large_test.dart -d macos
// pdfrx는 문서를 필요할 때 읽는 콜백(작업 스레드에만 묶임)으로 열어서, 읽지 않은 객체를 메인 스레드의 PDFium이 건드리면
// 앱이 죽는다. `PrintProcessor`가 먼저 문서를 한 번 통째로 저장해 두는 것을 지킨다 (그 줄을 빼면 이 시험이 앱을 죽인다).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('4 per sheet with page numbers on an 80 page, 16 MB document', (tester) async {
    await tester.runAsync(() async {
      await pdfrxFlutterInitialize();
      final doc = pw.Document();
      final noise = img.Image(width: 300, height: 300);
      for (var i = 0; i < 300 * 300; i++) {
        noise.setPixelRgb(i % 300, i ~/ 300, (i * 7919) & 255, (i * 104729) & 255, (i * 1299709) & 255);
      }
      final jpeg = img.encodeJpg(noise, quality: 95);
      for (var p = 0; p < 80; p++) {
        doc.addPage(
          pw.Page(
            build: (_) => pw.Column(
              children: [
                pw.Image(pw.MemoryImage(Uint8List.fromList([...jpeg, p & 255, (p >> 8) & 255])), width: 200),
                for (var i = 0; i < 25; i++)
                  pw.Text('Row $i of page $p', style: pw.TextStyle(font: pw.Font.helvetica())),
              ],
            ),
          ),
        );
      }
      final bytes = await doc.save();
      final out = await PrintProcessor.build(
        bytes,
        const PrintOptions(perSheet: 4, pageNumbers: PrintPageNumbers.bottomCenter),
        limit: 12,
        loadFont: () async => (await rootBundle.load('assets/fonts/seoul_namsan_regular.ttf')).buffer.asUint8List(),
      );
      final d = await PdfDocument.openData(out, sourceName: 'o');
      try {
        expect(d.pages.length, 12); // 앞 48쪽을 4쪽씩 = 12장
      } finally {
        d.dispose();
      }
    });
  });
}
