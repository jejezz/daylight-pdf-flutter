// 네이티브 PDFium이 필요해서 `flutter test`가 아니라 실제 앱에서 돈다:
//   flutter test integration_test -d macos
import 'dart:io';

import 'package:daylight_pdf/engine/pdf_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PdfrxEngine creates, saves, reopens and renders a PDF', (tester) async {
    await pdfrxFlutterInitialize();
    const engine = PdfrxEngine();

    final jpeg = img.encodeJpg(img.Image(width: 80, height: 60), quality: 80);
    final created = await PdfDocument.createFromJpegData(jpeg, width: 80, height: 60, sourceName: 'engine-test');
    addTearDown(created.dispose);

    final dir = Directory.systemTemp.createTempSync('daylight_pdf_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/out.pdf';
    await engine.save(created, path);

    final reopened = await engine.open(path);
    addTearDown(reopened.dispose);
    expect(reopened.pages, hasLength(1));
    expect(reopened.pages.first.width, 80);
    expect(reopened.pages.first.height, 60);
    final image = await reopened.pages.first.render(fullWidth: 80, fullHeight: 60);
    expect(image, isNotNull);
    image!.dispose();
  });
}
