// 실제 PDFium으로 인쇄 2차 기능(모아 찍기, 소책자, 쪽 번호, 워터마크, 흑백)을 확인한다:
//   flutter test integration_test/print_extra_test.dart -d macos
import 'dart:io';
import 'dart:typed_data';

import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/engine/annotations/annotation_specs.dart';
import 'package:daylight_pdf/engine/annotations/pdfium_annotations.dart';
import 'package:daylight_pdf/pages/page_ops.dart';
import 'package:daylight_pdf/print/print_options.dart';
import 'package:daylight_pdf/print/print_processor.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

typedef Rgb = (int, int, int);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  const colors = <Rgb>[(40, 170, 60), (220, 40, 40), (230, 200, 30), (140, 60, 190)];
  const a4 = PrintOptions(); // 595.28 x 841.89
  const white = (255, 255, 255);

  /// 색이 다른 [n]쪽(200x400)짜리 PDF 바이트. [rotateLast]면 마지막 쪽을 시계 방향 90° 돌린다.
  Future<Uint8List> makeSource(int n, {List<Rgb>? palette, bool rotateLast = false}) async {
    final inputs = <String>[];
    for (var i = 0; i < n; i++) {
      final c = (palette ?? colors)[i % (palette ?? colors).length];
      final image = img.Image(width: 200, height: 400)..clear(img.ColorRgb8(c.$1, c.$2, c.$3));
      inputs.add('${dir.path}/c$i.png');
      File(inputs[i]).writeAsBytesSync(img.encodePng(image));
    }
    await ImageToPdf.convert(inputs, '${dir.path}/s$n.pdf');
    if (rotateLast) {
      await PageOps.build([
        for (var i = 0; i < n; i++) PageRef('${dir.path}/s$n.pdf', i, quarterTurns: i == n - 1 ? 1 : 0),
      ], '${dir.path}/r$n.pdf');
      return File('${dir.path}/r$n.pdf').readAsBytesSync();
    }
    return File('${dir.path}/s$n.pdf').readAsBytesSync();
  }

  Future<({int width, int height, Uint8List bgra})> renderPage(Uint8List pdf, int index, {double scale = 1}) async {
    final doc = await PdfDocument.openData(pdf, sourceName: 'check');
    try {
      final page = doc.pages[index];
      final image = (await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
        backgroundColor: 0xFFFFFFFF,
      ))!;
      final copy = Uint8List.fromList(image.pixels);
      final out = (width: image.width, height: image.height, bgra: copy);
      image.dispose();
      return out;
    } finally {
      doc.dispose();
    }
  }

  Rgb at(({int width, int height, Uint8List bgra}) im, double x, double y) {
    final i = (y.round().clamp(0, im.height - 1) * im.width + x.round().clamp(0, im.width - 1)) * 4;
    return (im.bgra[i + 2], im.bgra[i + 1], im.bgra[i]);
  }

  bool near(Rgb a, Rgb b, [int tol = 28]) =>
      (a.$1 - b.$1).abs() <= tol && (a.$2 - b.$2).abs() <= tol && (a.$3 - b.$3).abs() <= tol;

  /// 상자 안에서 [base]와 뚜렷이 다른 픽셀 수 (글자가 찍혔는지 본다).
  int differing(({int width, int height, Uint8List bgra}) im, Rect box, Rgb base, [int tol = 14]) {
    var n = 0;
    for (var y = box.top.round(); y < box.bottom.round(); y++) {
      for (var x = box.left.round(); x < box.right.round(); x++) {
        if (!near(at(im, x.toDouble(), y.toDouble()), base, tol)) n++;
      }
    }
    return n;
  }

  Future<List<String>> sizes(Uint8List pdf) async {
    final doc = await PdfDocument.openData(pdf, sourceName: 'sizes');
    try {
      return [for (final p in doc.pages) '${p.width.round()}x${p.height.round()}'];
    } finally {
      doc.dispose();
    }
  }

  Future<Uint8List> run(Uint8List source, PrintOptions o, {Future<Uint8List> Function()? loadFont}) =>
      PrintProcessor.build(
        source,
        o,
        loadFont:
            loadFont ??
            () async => (await rootBundle.load('assets/fonts/seoul_namsan_regular.ttf')).buffer.asUint8List(),
      );

  setUpAll(() async {
    await pdfrxFlutterInitialize();
  });
  setUp(() => dir = Directory.systemTemp.createTempSync('daylight_pdf_print_extra'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('2 per sheet puts two pages side by side on a landscape sheet', (tester) async {
    await tester.runAsync(() async {
      final out = await run(await makeSource(4), a4.copyWith(perSheet: 2));
      expect(await sizes(out), ['842x595', '842x595']);
      final s0 = await renderPage(out, 0), s1 = await renderPage(out, 1);
      expect(near(at(s0, 421 / 2, 297), colors[0]), isTrue, reason: 'left cell = page 1');
      expect(near(at(s0, 421 * 1.5, 297), colors[1]), isTrue, reason: 'right cell = page 2');
      expect(near(at(s1, 421 / 2, 297), colors[2]), isTrue, reason: 'page 3');
      expect(near(at(s1, 421 * 1.5, 297), colors[3]), isTrue, reason: 'page 4');
    });
  });

  testWidgets('4 per sheet, an odd page count leaves the last cells empty, margins stay white, borders are drawn', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final o = a4.copyWith(perSheet: 4, marginMm: 10, sheetBorder: true);
      final out = await run(await makeSource(5), o);
      expect(await sizes(out), ['595x842', '595x842']);
      final s0 = await renderPage(out, 0), s1 = await renderPage(out, 1);
      // 2x2: 쪽 1 왼쪽 위, 2 오른쪽 위, 3 왼쪽 아래, 4 오른쪽 아래
      expect(near(at(s0, 150, 200), colors[0]), isTrue);
      expect(near(at(s0, 450, 200), colors[1]), isTrue);
      expect(near(at(s0, 150, 640), colors[2]), isTrue);
      expect(near(at(s0, 450, 640), colors[3]), isTrue);
      expect(near(at(s0, 5, 5), white), isTrue, reason: 'margin');
      // 둘째 장에는 5쪽(왼쪽 위)만 있고 나머지 칸은 비어 있다 (테두리도 쪽이 있는 칸만)
      expect(near(at(s1, 150, 200), colors[0]), isTrue, reason: 'page 5 is the first colour again');
      expect(near(at(s1, 450, 200), white), isTrue, reason: 'empty cell');
      // 테두리: 칸 가장자리(= 용지를 반으로 나눈 자리)에 얇은 회색 선이 있다. 칸 안쪽은 여백 때문에 흰색이다.
      var gray = 0;
      for (var y = 100; y < 300; y += 7) {
        if (!near(at(s0, 297.64, y.toDouble()), white, 14) || !near(at(s0, 296.64, y.toDouble()), white, 14)) gray++;
      }
      expect(gray, greaterThan(5), reason: 'border line between the two top cells');
    });
  });

  testWidgets('annotations survive 2-up (they are baked into the page)', (tester) async {
    await tester.runAsync(() async {
      final source = await makeSource(2);
      final doc = await PdfDocument.openData(source, sourceName: 'a');
      late Uint8List annotated;
      try {
        await PdfiumAnnotations.add(doc, [
          const ShapeSpec(
            pageIndex: 1,
            color: 0xFF0000FF,
            kind: ShapeKind.square,
            box: (left: 20, bottom: 20, right: 180, top: 380),
            width: 10,
          ),
        ]);
        annotated = await doc.encodePdf();
      } finally {
        doc.dispose();
      }
      final out = await run(annotated, a4.copyWith(perSheet: 2));
      final sheet = await renderPage(out, 0);
      // 오른쪽 칸(쪽 2): 칸 421x595에 200x400을 맞춤 → 배율 1.4875, 가로 들여쓰기 (421-297.5)/2. 파란 띠는 쪽 안 x≈25
      const scale = 595.28 / 400;
      final indent = 421 + (421 - 200 * scale) / 2;
      expect(near(at(sheet, indent + 25 * scale, 297), (0, 0, 255)), isTrue);
      expect(near(at(sheet, indent + 100 * scale, 297), colors[1]), isTrue);
    });
  });

  testWidgets('booklet orders the pages for folding and pads with blanks', (tester) async {
    await tester.runAsync(() async {
      final four = await run(await makeSource(4), a4.copyWith(booklet: true));
      expect(await sizes(four), ['842x595', '842x595']);
      final a = await renderPage(four, 0), b = await renderPage(four, 1);
      // 앞면: (4, 1), 뒷면: (2, 3)
      expect(near(at(a, 210, 297), colors[3]), isTrue, reason: 'front left = page 4');
      expect(near(at(a, 630, 297), colors[0]), isTrue, reason: 'front right = page 1');
      expect(near(at(b, 210, 297), colors[1]), isTrue, reason: 'back left = page 2');
      expect(near(at(b, 630, 297), colors[2]), isTrue, reason: 'back right = page 3');

      final five = await run(await makeSource(5), a4.copyWith(booklet: true));
      expect((await sizes(five)).length, 4, reason: '5 pages pad to 8 half pages = 4 output pages');
      final first = await renderPage(five, 0);
      expect(
        near(at(first, 210, 297), white),
        isTrue,
        reason: 'the last page of the 8 is blank, so the front left is empty',
      );
      expect(near(at(first, 630, 297), colors[0]), isTrue);
    });
  });

  testWidgets('page numbers use the original page number and land at the right place, also on a rotated page', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const whites = <Rgb>[(255, 255, 255)];
      final source = await makeSource(3, palette: whites, rotateLast: true);
      final plain = await run(source, a4.copyWith(range: '2-3'));
      final numbered = await run(
        source,
        a4.copyWith(range: '2-3', pageNumbers: PrintPageNumbers.bottomCenter, pageNumberTotal: true),
      );
      // 첫 출력 쪽(원래 2쪽, 세로): 아래 가운데에 "2 / 3"
      final p0 = await renderPage(plain, 0), n0 = await renderPage(numbered, 0);
      const bottomCenter = Rect.fromLTRB(250, 800, 350, 842);
      expect(differing(p0, bottomCenter, white), 0, reason: 'no number without the option');
      expect(differing(n0, bottomCenter, white), greaterThan(20), reason: 'number printed at bottom centre');
      expect(differing(n0, const Rect.fromLTRB(250, 0, 350, 42), white), 0, reason: 'nothing at the top');
      // 둘째 출력 쪽(원래 3쪽, 시계 방향 90° 돌린 쪽 = 보이는 쪽이 400x200 가로라서 용지도 가로 842x595): 숫자는 보이는 쪽 아래 가운데
      final n1 = await renderPage(numbered, 1);
      expect(n1.width, inInclusiveRange(841, 842));
      expect(n1.height, inInclusiveRange(595, 596));
      final cx = n1.width / 2, h1 = n1.height.toDouble();
      expect(
        differing(n1, Rect.fromLTRB(cx - 50, h1 - 42, cx + 50, h1), white),
        greaterThan(20),
        reason: 'rotated page: number still at the visible bottom',
      );
      expect(differing(n1, Rect.fromLTRB(cx - 50, 0, cx + 50, 42), white), 0);
      // 오른쪽 아래
      final right = await run(source, a4.copyWith(range: '1', pageNumbers: PrintPageNumbers.bottomRight));
      final r0 = await renderPage(right, 0);
      expect(differing(r0, const Rect.fromLTRB(500, 800, 580, 842), white), greaterThan(8));
      expect(differing(r0, bottomCenter, white), 0);
    });
  });

  testWidgets('a watermark (Korean too) is drawn across the page, and not without it', (tester) async {
    await tester.runAsync(() async {
      final source = await makeSource(1, palette: const [white]);
      final without = await renderPage(await run(source, a4), 0);
      final with_ = await renderPage(await run(source, a4.copyWith(watermark: '사본 DRAFT')), 0);
      const middle = Rect.fromLTRB(100, 250, 500, 600);
      expect(differing(without, middle, white), 0);
      expect(differing(with_, middle, white), greaterThan(500), reason: 'watermark ink in the middle');
    });
  });

  testWidgets('forced grayscale turns colour (also annotations) into grey and keeps the page count and size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final source = await makeSource(2);
      final doc = await PdfDocument.openData(source, sourceName: 'g');
      late Uint8List annotated;
      try {
        await PdfiumAnnotations.add(doc, [
          const ShapeSpec(
            pageIndex: 0,
            color: 0xFF0000FF,
            kind: ShapeKind.square,
            box: (left: 20, bottom: 20, right: 180, top: 380),
            width: 10,
          ),
        ]);
        annotated = await doc.encodePdf();
      } finally {
        doc.dispose();
      }
      final out = await run(annotated, a4.copyWith(grayscale: true));
      expect(await sizes(out), ['595x842', '595x842']);
      final p = await renderPage(out, 0), q = await renderPage(out, 1);
      for (final (x, y) in [(297.0, 421.0), (150.0, 300.0), (297.0, 700.0)]) {
        for (final shot in [p, q]) {
          final c = at(shot, x, y);
          expect((c.$1 - c.$2).abs(), lessThan(6), reason: 'grey at ($x, $y): $c');
          expect((c.$2 - c.$3).abs(), lessThan(6), reason: 'grey at ($x, $y): $c');
        }
      }
      // 색이 사라졌지만 구별은 남는다: 초록 쪽(밝기 ~120)과 빨강 쪽(밝기 ~90)은 다른 회색이다
      expect((at(p, 297, 421).$1 - at(q, 297, 421).$1).abs(), greaterThan(8));
    });
  });

  testWidgets('pages with fonts that are not embedded still print with every option on', (tester) async {
    await tester.runAsync(() async {
      // 포함되지 않은 TrueType "Arial"/"MalgunGothic" 글자가 든 PDF (글꼴 대체가 필요하다)
      final objs = <String>[
        '<< /Type /Catalog /Pages 2 0 R >>',
        '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>',
        '<< /Length 74 >>\nstream\nBT /F1 24 Tf 20 120 Td (Arial text) Tj /F2 24 Tf 0 -40 Td (Malgun) Tj ET\nendstream',
        '<< /Type /Font /Subtype /TrueType /BaseFont /Arial /Encoding /WinAnsiEncoding >>',
        '<< /Type /Font /Subtype /TrueType /BaseFont /MalgunGothic /Encoding /WinAnsiEncoding >>',
      ];
      final sb = StringBuffer('%PDF-1.4\n');
      final offsets = <int>[];
      for (var i = 0; i < objs.length; i++) {
        offsets.add(sb.length);
        sb.write('${i + 1} 0 obj\n${objs[i]}\nendobj\n');
      }
      final xref = sb.length;
      sb.write('xref\n0 ${objs.length + 1}\n0000000000 65535 f \n');
      for (final o in offsets) {
        sb.write('${o.toString().padLeft(10, '0')} 00000 n \n');
      }
      sb.write('trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
      final source = Uint8List.fromList(sb.toString().codeUnits);
      final o = a4.copyWith(
        perSheet: 2,
        sheetBorder: true,
        pageNumbers: PrintPageNumbers.bottomCenter,
        pageNumberTotal: true,
        watermark: '기밀',
        marginMm: 5,
      );
      final out = await run(source, o);
      expect((await sizes(out)).length, 1);
      final grayed = await run(source, o.copyWith(grayscale: true));
      expect((await sizes(grayed)).length, 1);
    });
  });
}
