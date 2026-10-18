// 실제 PDFium으로 인쇄용 PDF 가공을 확인한다:
//   flutter test integration_test/print_test.dart -d macos
import 'dart:io';
import 'dart:typed_data';

import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/engine/annotations/annotation_specs.dart';
import 'package:daylight_pdf/engine/annotations/pdfium_annotations.dart';
import 'package:daylight_pdf/pages/page_ops.dart';
import 'package:daylight_pdf/print/print_options.dart';
import 'package:daylight_pdf/print/print_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

typedef Rgb = (int, int, int);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late List<int> source; // 4쪽: 1 초록(200x400, 파란 테두리 주석), 2 빨강(200x400), 3 노랑(400x200 가로), 4 보라(200x400)
  const colors = <Rgb>[(40, 170, 60), (220, 40, 40), (230, 200, 30), (140, 60, 190)];
  const white = (255, 255, 255);

  Future<List<int>> makeSource({bool annotate = true}) async {
    final inputs = <String>[];
    const sizes = [(200, 400), (200, 400), (400, 200), (200, 400)];
    for (var i = 0; i < 4; i++) {
      final c = colors[i];
      final image = img.Image(width: sizes[i].$1, height: sizes[i].$2)..clear(img.ColorRgb8(c.$1, c.$2, c.$3));
      inputs.add('${dir.path}/c$i.png');
      File(inputs[i]).writeAsBytesSync(img.encodePng(image));
    }
    await ImageToPdf.convert(inputs, '${dir.path}/source.pdf');
    final doc = await PdfDocument.openFile('${dir.path}/source.pdf');
    try {
      if (annotate) {
        await PdfiumAnnotations.add(doc, [
          const ShapeSpec(
            pageIndex: 0,
            color: 0xFF0000FF,
            kind: ShapeKind.square,
            box: (left: 20, bottom: 20, right: 180, top: 380),
            width: 10,
          ),
        ]);
      }
      return await doc.encodePdf();
    } finally {
      doc.dispose();
    }
  }

  /// [pageIndex]쪽을 1pt = 1px로 그려 (x, y)(위가 0) 픽셀의 색을 돌려준다.
  Future<Rgb> pixel(List<int> pdf, int pageIndex, double x, double y) async {
    final doc = await PdfDocument.openData(pdf as dynamic, sourceName: 'check');
    try {
      final page = doc.pages[pageIndex];
      final image = (await page.render(
        fullWidth: page.width,
        fullHeight: page.height,
        backgroundColor: 0xFFFFFFFF,
        annotationRenderingMode: PdfAnnotationRenderingMode.annotationAndForms,
      ))!;
      final i = (y.round().clamp(0, image.height - 1) * image.width + x.round().clamp(0, image.width - 1)) * 4;
      final bgr = (image.pixels[i + 2], image.pixels[i + 1], image.pixels[i]);
      image.dispose();
      return bgr;
    } finally {
      doc.dispose();
    }
  }

  Future<List<String>> sizes(List<int> pdf) async {
    final doc = await PdfDocument.openData(pdf as dynamic, sourceName: 'sizes');
    try {
      return [for (final p in doc.pages) '${p.width.round()}x${p.height.round()}'];
    } finally {
      doc.dispose();
    }
  }

  bool near(Rgb a, Rgb b) => (a.$1 - b.$1).abs() < 25 && (a.$2 - b.$2).abs() < 25 && (a.$3 - b.$3).abs() < 25;

  setUpAll(() async {
    await pdfrxFlutterInitialize();
  });

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('daylight_pdf_print');
    source = await makeSource();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<List<int>> run(PrintOptions o, {int currentPage = 1, List<int>? from}) =>
      PrintProcessor.build(Uint8List.fromList(from ?? source), o, currentPage: currentPage);

  const a4 = PrintOptions(); // 595.28 x 841.89, 크기 맞춤, 여백 0

  testWidgets('range, odd/even and reverse choose and order the pages', (tester) async {
    await tester.runAsync(() async {
      Future<List<bool>> order(PrintOptions o, List<int> expectColorIndexes) async {
        final out = await run(o);
        expect((await sizes(out)).length, expectColorIndexes.length);
        final ok = <bool>[];
        for (var i = 0; i < expectColorIndexes.length; i++) {
          final doc = await PdfDocument.openData(out as dynamic, sourceName: 'x');
          final page = doc.pages[i];
          final c = await pixel(out, i, page.width / 2, page.height / 2);
          doc.dispose();
          ok.add(near(c, colors[expectColorIndexes[i]]));
        }
        return ok;
      }

      expect(await order(a4, [0, 1, 2, 3]), everyElement(isTrue));
      expect(await order(a4.copyWith(range: '2-4', reverse: true), [3, 2, 1]), everyElement(isTrue));
      expect(await order(a4.copyWith(parity: PrintParity.odd), [0, 2]), everyElement(isTrue));
      expect(await order(a4.copyWith(range: 'current'), [0]), everyElement(isTrue));
      expect((await sizes(await run(a4.copyWith(range: 'current'), currentPage: 2))).length, 1);
    });
  });

  testWidgets('every page becomes paper sized, a landscape page turns the paper', (tester) async {
    await tester.runAsync(() async {
      expect(await sizes(await run(a4)), ['595x842', '595x842', '842x595', '595x842']);
      expect(await sizes(await run(a4.copyWith(autoOrientation: false))), everyElement('595x842'));
      expect(await sizes(await run(a4.copyWith(paperWidth: 612, paperHeight: 792))), [
        '612x792',
        '612x792',
        '792x612',
        '612x792',
      ]);
    });
  });

  testWidgets('annotations are printed or left out', (tester) async {
    await tester.runAsync(() async {
      // 쪽 1(200x400)을 A4에 크기 맞춤: 세로가 한계라 배율 841.89/400, 가로는 가운데로 (595.28 - 200·배율)/2 만큼 들어간다.
      // 파란 테두리는 쪽 안 x=20..30 → 용지 위 x = 들여쓰기 + 25·배율
      final scale = 841.89 / 400;
      final indent = (595.28 - 200 * scale) / 2;
      const blue = (0, 0, 255);
      expect(near(await pixel(source, 0, 25, 200), blue), isTrue, reason: 'the source itself shows the annotation');
      final withAnnot = await run(a4);
      final probeX = indent + 25 * scale, probeY = 841.89 / 2;
      expect(near(await pixel(withAnnot, 0, probeX, probeY), blue), isTrue, reason: 'annotation printed');
      final without = await run(a4.copyWith(includeAnnotations: false));
      expect(near(await pixel(without, 0, probeX, probeY), colors[0]), isTrue, reason: 'annotation left out');
      // 원본은 그대로: 다시 읽어도 주석이 있다
      final reread = await PdfDocument.openData(Uint8List.fromList(source) as dynamic, sourceName: 'src');
      expect((await PdfiumAnnotations.read(reread)).length, 1);
      reread.dispose();
    });
  });

  testWidgets('margins stay white and the page keeps its proportion; actual size does not scale', (tester) async {
    await tester.runAsync(() async {
      // 여백 20mm = 56.7pt. 쪽 2(빨강 200x400)는 세로가 한계: 높이 841.89-113.4=728.5 → 배율 1.82, 너비 364
      final out = await run(a4.copyWith(marginMm: 20));
      expect(near(await pixel(out, 1, 595.28 / 2, 20), white), isTrue, reason: 'top margin');
      expect(near(await pixel(out, 1, 595.28 / 2, 841.89 / 2), colors[1]), isTrue, reason: 'centre');
      expect(near(await pixel(out, 1, 595.28 / 2, 841.89 - 20), white), isTrue, reason: 'bottom margin');
      expect(near(await pixel(out, 1, 595.28 / 2 - 190, 841.89 / 2), white), isTrue, reason: 'side of the scaled page');
      expect(
        near(await pixel(out, 1, 595.28 / 2 - 170, 841.89 / 2), colors[1]),
        isTrue,
        reason: 'inside the scaled page',
      );

      // 원래 크기: 200x400이 그대로 가운데에
      final actual = await run(a4.copyWith(scale: PrintScale.actual));
      expect(near(await pixel(actual, 1, 595.28 / 2, 841.89 / 2), colors[1]), isTrue);
      expect(near(await pixel(actual, 1, 595.28 / 2 + 90, 841.89 / 2), colors[1]), isTrue, reason: 'inside 200pt');
      expect(near(await pixel(actual, 1, 595.28 / 2 + 110, 841.89 / 2), white), isTrue, reason: 'outside 200pt');
      expect(near(await pixel(actual, 1, 595.28 / 2, 841.89 / 2 + 190), colors[1]), isTrue, reason: 'inside 400pt');
      expect(near(await pixel(actual, 1, 595.28 / 2, 841.89 / 2 + 210), white), isTrue, reason: 'outside 400pt');
    });
  });

  testWidgets('a page rotated by 90 degrees prints the way the viewer shows it', (tester) async {
    await tester.runAsync(() async {
      // 원본 쪽 1(초록 200x400, 파란 테두리)을 시계 방향 90° 돌린 문서를 만든다
      await PageOps.build([PageRef('${dir.path}/source.pdf', 1, quarterTurns: 1)], '${dir.path}/turned.pdf');
      // 위쪽 왼쪽에 표시를 하려고 주석 대신 색이 다른 쪽을 쓴다: 쪽 3(노랑 400x200)을 돌린 것은 세로 200x400이 된다
      await PageOps.build([PageRef('${dir.path}/source.pdf', 2, quarterTurns: 1)], '${dir.path}/turned3.pdf');
      final turned = await File('${dir.path}/turned3.pdf').readAsBytes();
      expect(await sizes(turned), ['200x400']);
      final out = await run(a4, from: turned);
      expect(await sizes(out), ['595x842']);
      expect(near(await pixel(out, 0, 595.28 / 2, 841.89 / 2), colors[2]), isTrue);
      expect(near(await pixel(out, 0, 5, 5), white), isTrue, reason: 'outside the scaled page is paper');
      expect(near(await pixel(out, 0, 100, 5), colors[2]), isTrue, reason: 'top edge of the scaled page');
    });
  });
}
