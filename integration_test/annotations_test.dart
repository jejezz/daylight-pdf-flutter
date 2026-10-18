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

  group('note icon appearance', () {
    late Directory dir;
    late PdfDocument document;

    setUp(() async {
      await pdfrxFlutterInitialize();
      dir = Directory.systemTemp.createTempSync('daylight_pdf_icon');
      File('${dir.path}/b.png')
          .writeAsBytesSync(img.encodePng(img.Image(width: 400, height: 300)..clear(img.ColorRgb8(255, 255, 255))));
      await ImageToPdf.convert(['${dir.path}/b.png'], '${dir.path}/base.pdf');
      document = await PdfDocument.openFile('${dir.path}/base.pdf');
    });
    tearDown(() {
      document.dispose();
      dir.deleteSync(recursive: true);
    });

    /// 저장하고 다시 열어 [scale]배로 그린 픽셀 읽기 (페이지 좌표 pt → 화면, y는 아래에서 위로).
    Future<({PdfDocument saved, (int, int, int) Function(double x, double y) at})> saveAndRender(int scale) async {
      final path = '${dir.path}/saved.pdf';
      File(path).writeAsBytesSync(await document.encodePdf());
      final saved = await PdfDocument.openFile(path);
      addTearDown(saved.dispose);
      final image = (await saved.pages.first.render(
        fullWidth: 400.0 * scale,
        fullHeight: 300.0 * scale,
        backgroundColor: 0xFFFFFFFF,
      ))!;
      addTearDown(image.dispose);
      (int, int, int) at(double x, double y) {
        final px = (x * scale).round(), py = ((300 - y) * scale).round();
        final i = (py * image.width + px) * 4;
        return (image.pixels[i + 2], image.pixels[i + 1], image.pixels[i]); // R, G, B
      }

      return (saved: saved, at: at);
    }

    testWidgets('a custom SVG becomes the appearance of the note and survives save and reopen', (tester) async {
      await PdfiumAnnotations.add(document, [
        const NoteSpec(
          pageIndex: 0,
          color: 0xFFFFEB3B,
          x: 100,
          y: 100,
          text: '아이콘 있는 메모',
          iconSvg:
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
              '<rect width="24" height="24" fill="#33b34d"/><rect x="6" y="6" width="12" height="12" fill="#ffffff"/></svg>',
        ),
      ]);
      final r = await saveAndRender(4);
      expect(r.at(102, 122), (51, 179, 77), reason: 'the corner of the icon is its green square');
      expect(r.at(112, 112), (255, 255, 255), reason: 'the middle is the white inner square');
      expect(r.at(200, 200), (255, 255, 255), reason: 'nothing is drawn outside the note');

      final notes = await PdfiumAnnotations.read(r.saved);
      expect(notes.single.subtype, 1, reason: 'it is still a standard text (note) annotation');
      expect(notes.single.contents, '아이콘 있는 메모');
      expect(
        [notes.single.rect.left, notes.single.rect.bottom, notes.single.rect.right, notes.single.rect.top],
        [100, 100, 124, 124],
      );
    });

    testWidgets('the bundled sticker icon draws its paper and outline in the right places', (tester) async {
      final svg = File('assets/annotations/note_icon.svg').readAsStringSync();
      await PdfiumAnnotations.add(document, [
        NoteSpec(pageIndex: 0, color: 0xFFFFEB3B, x: 50, y: 150, text: '스티커 메모', iconSvg: svg),
      ]);
      final r = await saveAndRender(8);
      // 다른 뷰어(미리보기 등)로 열어 볼 수 있게 시스템 임시 폴더에도 남긴다.
      File('${dir.path}/saved.pdf').copySync('${Directory.systemTemp.path}/daylight_pdf_note_icon.pdf');
      // 100x100 아이콘이 (50,150)~(74,174) 24pt에 들어간다: 배율 0.24, 아이콘 (vx, vy) → 페이지 (50+0.24vx, 174-0.24vy)
      (double, double) page(double vx, double vy) => (50 + 0.24 * vx, 174 - 0.24 * vy);
      bool near((int, int, int) c, int r, int g, int b) =>
          (c.$1 - r).abs() < 12 && (c.$2 - g).abs() < 12 && (c.$3 - b).abs() < 12;

      final paper = page(50, 58);
      expect(
        near(r.at(paper.$1, paper.$2), 255, 227, 133),
        isTrue,
        reason: 'paper #ffe385 at ${r.at(paper.$1, paper.$2)}',
      );
      final outline = page(15.5, 50); // 왼쪽 남색 테두리 (x 14~17)
      expect(
        near(r.at(outline.$1, outline.$2), 64, 57, 110),
        isTrue,
        reason: 'outline #40396e at ${r.at(outline.$1, outline.$2)}',
      );
      final line = page(50, 28); // 첫째 주황 글줄
      expect(near(r.at(line.$1, line.$2), 249, 184, 79), isTrue, reason: 'line #f9b84f at ${r.at(line.$1, line.$2)}');
      expect(r.at(200, 100), (255, 255, 255), reason: 'nothing outside the note');
    });

    testWidgets('an SVG that cannot be converted still creates the note (the viewer shows its own icon)', (
      tester,
    ) async {
      await PdfiumAnnotations.add(document, [
        const NoteSpec(pageIndex: 0, color: 0xFFFFEB3B, x: 10, y: 10, text: '그래도 메모', iconSvg: '<svg'),
        const NoteSpec(
          pageIndex: 0,
          color: 0xFFFFEB3B,
          x: 50,
          y: 10,
          text: '그릴 게 없는 SVG',
          iconSvg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><text>x</text></svg>',
        ),
      ]);
      final notes = await PdfiumAnnotations.read(document);
      expect(notes.map((n) => n.contents), ['그래도 메모', '그릴 게 없는 SVG']);
      expect(notes.every((n) => n.subtype == 1), isTrue);
    });
  });
}
