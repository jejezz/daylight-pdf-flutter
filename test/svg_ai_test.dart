import 'dart:io';

import 'package:daylight_pdf/convert/ai_to_pdf.dart';
import 'package:daylight_pdf/convert/conversion_error.dart';
import 'package:daylight_pdf/convert/svg_to_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('daylight_pdf_svg_ai'));
  tearDown(() => dir.deleteSync(recursive: true));

  String write(String name, String text) {
    final path = '${dir.path}/$name';
    File(path).writeAsStringSync(text);
    return path;
  }

  Matcher failsWith(ConversionErrorKind kind) =>
      throwsA(isA<ConversionException>().having((e) => e.kind, 'kind', kind));

  group('SvgToPdf.pageSize', () {
    test('converts px, mm and in to points (px = 0.75pt)', () {
      expect(SvgToPdf.pageSize('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"/>')!.width, 75);
      expect(SvgToPdf.pageSize('<svg xmlns="http://www.w3.org/2000/svg" width="1in" height="2in"/>')!.height, 144);
      final mm = SvgToPdf.pageSize('<svg xmlns="http://www.w3.org/2000/svg" width="210mm" height="297mm"/>')!;
      expect(mm.width, closeTo(595.28, 0.01));
      expect(mm.height, closeTo(841.89, 0.01));
    });

    test('falls back to the viewBox when width/height are missing or relative', () {
      final a = SvgToPdf.pageSize('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200"/>')!;
      expect([a.width, a.height], [300, 150]);
      final b = SvgToPdf.pageSize(
        '<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="0,0,80,40"/>',
      )!;
      expect([b.width, b.height], [60, 30]);
    });

    test('rejects non-SVG, broken XML and SVGs with no size at all', () {
      expect(SvgToPdf.pageSize('<html/>'), isNull);
      expect(SvgToPdf.pageSize('<svg'), isNull);
      expect(SvgToPdf.pageSize('<svg xmlns="http://www.w3.org/2000/svg"/>'), isNull);
    });
  });

  group('SvgToPdf.convert', () {
    test('writes a one-page PDF sized from the SVG', () async {
      final input = write(
        'a.svg',
        '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100"><rect width="200" height="100" fill="red"/></svg>',
      );
      final out = '${dir.path}/a.pdf';
      await SvgToPdf.convert(input, out);
      final text = String.fromCharCodes(File(out).readAsBytesSync());
      expect(text, startsWith('%PDF'));
      expect(RegExp(r'/MediaBox\s*\[\s*0\s+0\s+150\s+75\s*\]').hasMatch(text), isTrue);
    });

    test('reports a broken SVG and writes nothing', () async {
      final input = write('bad.svg', '<svg width="10"');
      final out = '${dir.path}/bad.pdf';
      await expectLater(SvgToPdf.convert(input, out), failsWith(ConversionErrorKind.cannotRead));
      expect(File(out).existsSync(), isFalse);
    });
  });

  group('AiToPdf', () {
    test('supports .ai only', () {
      expect(AiToPdf.supports('/a/logo.AI'), isTrue);
      expect(AiToPdf.supports('/a/logo.eps'), isFalse);
    });

    test('sniffs PDF-compatible, PostScript and unknown content', () {
      expect(AiToPdf.sniff('%PDF-1.6\n...'.codeUnits), AiKind.pdfCompatible);
      expect(AiToPdf.sniff('junk\n%PDF-1.5'.codeUnits), AiKind.pdfCompatible);
      expect(AiToPdf.sniff('%!PS-Adobe-3.0 EPSF-3.0\n%%Creator: Adobe Illustrator'.codeUnits), AiKind.postScript);
      expect(AiToPdf.sniff('hello'.codeUnits), AiKind.unknown);
      expect(AiToPdf.sniff(const []), AiKind.unknown);
    });

    test('a PostScript .ai is not forced into a PDF', () async {
      final input = write('old.ai', '%!PS-Adobe-3.0 EPSF-3.0\n%%Creator: Adobe Illustrator\n');
      final out = '${dir.path}/old.pdf';
      await expectLater(AiToPdf.convert(input, out), failsWith(ConversionErrorKind.notPdfCompatible));
      expect(File(out).existsSync(), isFalse);
    });

    test('an unrecognised .ai is reported as unreadable', () async {
      final input = write('odd.ai', 'not an illustrator file');
      await expectLater(AiToPdf.convert(input, '${dir.path}/o.pdf'), failsWith(ConversionErrorKind.cannotRead));
    });
  });
}
