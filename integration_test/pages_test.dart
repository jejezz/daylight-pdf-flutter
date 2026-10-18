// 네이티브 PDFium이 필요해서 `flutter test`가 아니라 실제 앱에서 돈다:
//   flutter test integration_test/pages_test.dart -d macos
import 'dart:io';

import 'package:daylight_pdf/convert/conversion_error.dart';
import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/pages/page_ops.dart';
import 'package:daylight_pdf/pages/page_ranges.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late String abc; // 3쪽: 100x50, 60x120, 80x80 (크기로 쪽을 구별한다)
  late String xy; // 2쪽: 200x100, 40x40

  Future<void> makePdf(String name, List<(int, int)> sizes) async {
    final inputs = <String>[];
    for (var i = 0; i < sizes.length; i++) {
      final path = '${dir.path}/$name-$i.png';
      File(path).writeAsBytesSync(img.encodePng(img.Image(width: sizes[i].$1, height: sizes[i].$2)));
      inputs.add(path);
    }
    await ImageToPdf.convert(inputs, '${dir.path}/$name.pdf');
  }

  Future<List<String>> sizesOf(String path) async {
    final doc = await PdfDocument.openFile(path);
    try {
      return [for (final page in doc.pages) '${page.width.round()}x${page.height.round()}'];
    } finally {
      doc.dispose();
    }
  }

  setUp(() async {
    await pdfrxFlutterInitialize();
    dir = Directory.systemTemp.createTempSync('daylight_pdf_pages');
    await makePdf('abc', [(100, 50), (60, 120), (80, 80)]);
    await makePdf('xy', [(200, 100), (40, 40)]);
    abc = '${dir.path}/abc.pdf';
    xy = '${dir.path}/xy.pdf';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('merge keeps order across files', (tester) async {
    await PageOps.merge([xy, abc], '${dir.path}/m.pdf');
    expect(await sizesOf('${dir.path}/m.pdf'), ['200x100', '40x40', '100x50', '60x120', '80x80']);
  });

  testWidgets('build reorders, rotates (swapping width/height) and deletes by omission', (tester) async {
    await PageOps.build([PageRef(abc, 2), PageRef(abc, 0, quarterTurns: 1), PageRef(abc, 0)], '${dir.path}/e.pdf');
    // 80x80 | 첫 쪽을 90° 돌려 50x100 | 돌리지 않은 첫 쪽 100x50. 둘째 쪽(60x120)은 빠졌다.
    expect(await sizesOf('${dir.path}/e.pdf'), ['80x80', '50x100', '100x50']);
  });

  testWidgets('rotation adds up and wraps around', (tester) async {
    await PageOps.build([PageRef(abc, 0, quarterTurns: 4), PageRef(abc, 0, quarterTurns: 5)], '${dir.path}/r.pdf');
    expect(await sizesOf('${dir.path}/r.pdf'), ['100x50', '50x100']);
  });

  testWidgets('split writes one numbered PDF per group and never overwrites', (tester) async {
    final out = '${dir.path}/out';
    final files = await PageOps.split(abc, out, parsePageGroups('1-2, 3', 3));
    expect(files.map((f) => f.split('/').last), ['abc-1.pdf', 'abc-2.pdf']);
    expect(await sizesOf(files[0]), ['100x50', '60x120']);
    expect(await sizesOf(files[1]), ['80x80']);

    final again = await PageOps.split(abc, out, splitEveryN(3, 3));
    expect(again.single.split('/').last, 'abc-1 (1).pdf');
    expect(await sizesOf(files[0]), ['100x50', '60x120'], reason: 'first run untouched');
  });

  testWidgets('extract = build from a typed list; the same page may repeat', (tester) async {
    await PageOps.build([for (final n in parsePageList('3, 1, 3', 3)) PageRef(abc, n - 1)], '${dir.path}/x.pdf');
    expect(await sizesOf('${dir.path}/x.pdf'), ['80x80', '100x50', '80x80']);
  });

  testWidgets('output may replace a source file (written only after all documents are closed)', (tester) async {
    await PageOps.build([PageRef(abc, 1), PageRef(abc, 0)], abc);
    expect(await sizesOf(abc), ['60x120', '100x50']);
    expect(File('$abc.tmp').existsSync(), isFalse);
  });

  testWidgets('errors are typed and leave no output', (tester) async {
    File('${dir.path}/fake.pdf').writeAsStringSync('not a pdf');
    Matcher fails(ConversionErrorKind k) => throwsA(isA<ConversionException>().having((e) => e.kind, 'kind', k));
    await expectLater(
      PageOps.merge([abc, '${dir.path}/fake.pdf'], '${dir.path}/bad.pdf'),
      fails(ConversionErrorKind.cannotRead),
    );
    await expectLater(
      PageOps.build([PageRef(abc, 9)], '${dir.path}/bad.pdf'),
      fails(ConversionErrorKind.invalidPageRange),
    );
    await expectLater(PageOps.build(const [], '${dir.path}/bad.pdf'), fails(ConversionErrorKind.invalidPageRange));
    expect(File('${dir.path}/bad.pdf').existsSync(), isFalse);
  });
}
