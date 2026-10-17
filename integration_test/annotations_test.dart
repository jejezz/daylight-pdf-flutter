// 네이티브 PDFium이 필요해서 `flutter test`가 아니라 실제 앱에서 돈다:
//   flutter test integration_test/annotations_test.dart -d macos
//
// 결과 PDF는 다른 뷰어(미리보기 등)로 열어 볼 수 있게 시스템 임시 폴더의 고정 이름으로도 남긴다.
import 'dart:io';

import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/engine/annotations/annotation_specs.dart';
import 'package:daylight_pdf/engine/annotations/pdfium_annotations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('annotations written with PDFium survive save, reload and rendering', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_annot');
    addTearDown(() => dir.deleteSync(recursive: true));
    final png = img.Image(width: 400, height: 300)..clear(img.ColorRgb8(255, 255, 255));
    File('${dir.path}/base.png').writeAsBytesSync(img.encodePng(png));
    await ImageToPdf.convert(['${dir.path}/base.png'], '${dir.path}/base.pdf');

    final document = await PdfDocument.openFile('${dir.path}/base.pdf');
    addTearDown(document.dispose);
    expect(document.pages.single.width, 400);

    await PdfiumAnnotations.add(document, [
      const HighlightSpec(
        pageIndex: 0,
        color: 0xFFFFEB3B,
        boxes: [(left: 40, bottom: 230, right: 200, top: 250), (left: 40, bottom: 205, right: 120, top: 225)],
      ),
      const UnderlineSpec(pageIndex: 0, color: 0xFFE53935, boxes: [(left: 40, bottom: 150, right: 200, top: 170)]),
      const NoteSpec(pageIndex: 0, color: 0xFFFFC107, x: 300, y: 250, text: '메모 테스트 note ✓'),
      InkSpec(
        pageIndex: 0,
        color: 0xFF1E88E5,
        width: 3,
        strokes: [
          [for (var i = 0; i <= 20; i++) (x: 40.0 + i * 8, y: 80.0 + (i.isEven ? 0.0 : 20.0))],
        ],
      ),
      const ShapeSpec(
        pageIndex: 0,
        color: 0xFF43A047,
        kind: ShapeKind.square,
        box: (left: 250, bottom: 100, right: 340, top: 160),
        width: 3,
      ),
      const ShapeSpec(
        pageIndex: 0,
        color: 0xFF8E24AA,
        kind: ShapeKind.circle,
        box: (left: 300, bottom: 20, right: 380, top: 80),
        width: 3,
      ),
    ]);

    // 저장 → 다시 열기
    final bytes = await document.encodePdf();
    final share = File('${Directory.systemTemp.path}/daylight_pdf_annot_spike.pdf')..writeAsBytesSync(bytes);
    final saved = '${dir.path}/annotated.pdf';
    File(saved).writeAsBytesSync(bytes);
    final reopened = await PdfDocument.openFile(saved);
    addTearDown(reopened.dispose);

    final annotations = await PdfiumAnnotations.read(reopened);
    expect(annotations.map((a) => a.subtype), [9, 10, 1, 15, 5, 6]);
    expect(annotations[2].contents, '메모 테스트 note ✓');

    // 렌더링에 주석이 그려진다 (PDFium이 만든 외형)
    final image = (await reopened.pages.first.render(fullWidth: 400, fullHeight: 300, backgroundColor: 0xFFFFFFFF))!;
    addTearDown(image.dispose);
    int px(int x, int yFromTop) {
      final i = (yFromTop * image.width + x) * 4;
      return (image.pixels[i + 2] << 16) | (image.pixels[i + 1] << 8) | image.pixels[i]; // BGRA → 0xRRGGBB
    }

    final highlight = px(100, 300 - 240); // 형광펜 안쪽
    expect(highlight, isNot(0xFFFFFF), reason: 'highlight must tint the page');
    expect((highlight >> 16) & 0xFF, greaterThan(200)); // 노란색: R, G 높고 B 낮음
    expect(highlight & 0xFF, lessThan(200));
    final inkColored = [for (var x = 40; x < 200; x++) px(x, 300 - 90)].any((c) => c != 0xFFFFFF);
    expect(inkColored, isTrue, reason: 'ink stroke must be drawn');

    // 메모 아이콘이 어디에 있는지 읽을 수 있다 (x: 300, y: 250에서 24pt 정사각형)
    final noteRect = annotations[2].rect;
    expect([noteRect.left, noteRect.bottom, noteRect.right, noteRect.top], [300, 250, 324, 274]);

    // 메모 고치기: 한글 내용으로 바꾸고 저장해 다시 열어도 남아 있다
    await PdfiumAnnotations.setContents(reopened, 0, 2, '고친 메모 ✓ edited');
    expect((await PdfiumAnnotations.read(reopened))[2].contents, '고친 메모 ✓ edited');
    final editedPath = '${dir.path}/edited.pdf';
    File(editedPath).writeAsBytesSync(await reopened.encodePdf());
    final edited = await PdfDocument.openFile(editedPath);
    addTearDown(edited.dispose);
    final editedAnnotations = await PdfiumAnnotations.read(edited);
    expect(editedAnnotations.map((a) => a.subtype), [9, 10, 1, 15, 5, 6], reason: 'editing keeps every annotation');
    expect(editedAnnotations[2].contents, '고친 메모 ✓ edited');
    expect(editedAnnotations[0].contents, isEmpty, reason: 'other annotations are untouched');

    // 지우기: 손글씨(3번째 위치 index 3)를 지우면 나머지 순서는 그대로
    await PdfiumAnnotations.remove(reopened, 0, 3);
    expect((await PdfiumAnnotations.read(reopened)).map((a) => a.subtype), [9, 10, 1, 5, 6]);
    final afterRemove = await reopened.encodePdf();
    File('${dir.path}/removed.pdf').writeAsBytesSync(afterRemove);
    final again = await PdfDocument.openFile('${dir.path}/removed.pdf');
    addTearDown(again.dispose);
    expect((await PdfiumAnnotations.read(again)).map((a) => a.subtype), [
      9,
      10,
      1,
      5,
      6,
    ], reason: 'removal survives save');

    // ignore: avoid_print
    print('SPIKE_OUTPUT ${share.path}');
  });

  testWidgets('a highlight lets dark content show through (multiply), it does not cover it', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_annot');
    addTearDown(() => dir.deleteSync(recursive: true));
    // 흰 바탕의 왼쪽 절반만 검정: 글자 대신 쓰는 어두운 내용
    final png = img.Image(width: 200, height: 100)..clear(img.ColorRgb8(255, 255, 255));
    img.fillRect(png, x1: 0, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(0, 0, 0));
    File('${dir.path}/base.png').writeAsBytesSync(img.encodePng(png));
    await ImageToPdf.convert(['${dir.path}/base.png'], '${dir.path}/base.pdf');

    final document = await PdfDocument.openFile('${dir.path}/base.pdf');
    addTearDown(document.dispose);
    await PdfiumAnnotations.add(document, [
      const HighlightSpec(pageIndex: 0, color: 0xFFFFEB3B, boxes: [(left: 0, bottom: 0, right: 200, top: 100)]),
    ]);
    final image = (await document.pages.first.render(fullWidth: 200, fullHeight: 100, backgroundColor: 0xFFFFFFFF))!;
    addTearDown(image.dispose);
    int channel(int x, int y, int c) => image.pixels[(y * image.width + x) * 4 + c]; // B, G, R

    expect(
      [channel(50, 50, 2), channel(50, 50, 1), channel(50, 50, 0)],
      everyElement(lessThan(60)),
      reason: 'black stays dark',
    );
    expect(channel(150, 50, 2), greaterThan(200), reason: 'white becomes yellow: R high');
    expect(channel(150, 50, 0), lessThan(200), reason: 'white becomes yellow: B low');

    File('${Directory.systemTemp.path}/daylight_pdf_annot_multiply.pdf').writeAsBytesSync(await document.encodePdf());
  });
}
