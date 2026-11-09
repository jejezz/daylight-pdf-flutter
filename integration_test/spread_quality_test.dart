// 실제 PDFium으로 펼침면 나누기의 결과 품질을 본다 (그려지는 내용, 용량):
//   flutter test integration_test/spread_quality_test.dart -d windows
import 'dart:io';

import 'package:daylight_pdf/pages/page_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'raw_pdf.dart';

/// 쪽을 작게 그려 (빨강 화소 수, 파랑 화소 수, 전체)를 센다.
Future<(int, int, int)> colors(PdfPage page) async {
  final bmp = await page.render(fullWidth: 120, fullHeight: 120 * page.height / page.width);
  final px = bmp!.pixels;
  var red = 0, blue = 0;
  for (var k = 0; k < px.length; k += 4) {
    // BGRA
    if (px[k + 2] > 150 && px[k] < 100) red++;
    if (px[k] > 150 && px[k + 2] < 100) blue++;
  }
  return (red, blue, px.length ~/ 4);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() async {
    await pdfrxFlutterInitialize();
    dir = Directory.systemTemp.createTempSync('daylight_pdf_spread_quality');
  });
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows는 PDFium이 아직 쥔 파일을 지우지 못할 수 있다. 임시 폴더라 둔다.
    }
  });

  testWidgets('split halves show the left and right side, and shared images are not copied per page', (tester) async {
    final input = '${dir.path}/in.pdf';
    File(input).writeAsBytesSync(sharedImagePdf(pages: 8));
    await PageOps.splitSpreads(input, '${dir.path}/out.pdf', {for (var i = 1; i <= 8; i++) i});

    final inSize = File(input).lengthSync(), outSize = File('${dir.path}/out.pdf').lengthSync();
    // 16쪽이 같은 이미지 하나를 같이 쓴다: 쪽마다 복사하면 8배가 넘게 늘어난다.
    expect(outSize, lessThan(inSize * 1.5), reason: 'in=$inSize out=$outSize');

    final doc = await PdfDocument.openFile('${dir.path}/out.pdf');
    addTearDown(doc.dispose);
    expect(doc.pages.length, 16);
    for (var i = 0; i < 16; i++) {
      final (red, blue, total) = await colors(doc.pages[i]);
      // 왼쪽 면은 온통 빨강, 오른쪽 면은 온통 파랑 — 빈 쪽이거나 반쪽이 섞이면 안 된다.
      if (i.isEven) {
        expect(red, greaterThan(total * 0.95), reason: 'page ${i + 1} should be the left (red) half');
        expect(blue, 0);
      } else {
        expect(blue, greaterThan(total * 0.95), reason: 'page ${i + 1} should be the right (blue) half');
        expect(red, 0);
      }
    }
  });

  testWidgets('merging and extracting no longer multiplies the size of shared objects either', (tester) async {
    final input = '${dir.path}/in.pdf';
    File(input).writeAsBytesSync(sharedImagePdf(pages: 8));
    await PageOps.build([for (var i = 0; i < 8; i++) PageRef(input, i)], '${dir.path}/same.pdf');
    expect(File('${dir.path}/same.pdf').lengthSync(), lessThan(File(input).lengthSync() * 1.5));
  });

  testWidgets('rotated pages are split along the visible middle and still show content', (tester) async {
    final input = '${dir.path}/in.pdf';
    File(input).writeAsBytesSync(sharedImagePdf(pages: 1));
    // 돌려서 위/아래가 되는 쪽: 보이는 왼쪽·오른쪽은 90° 돌린 뒤 기준이다.
    await PageOps.build([PageRef(input, 0, quarterTurns: 2)], '${dir.path}/r.pdf'); // 180°: 좌우가 뒤바뀐다
    await PageOps.splitSpreads('${dir.path}/r.pdf', '${dir.path}/o.pdf', {1});
    final doc = await PdfDocument.openFile('${dir.path}/o.pdf');
    addTearDown(doc.dispose);
    final (r0, b0, t0) = await colors(doc.pages[0]);
    final (r1, b1, t1) = await colors(doc.pages[1]);
    // 180° 돌렸으니 보이는 왼쪽은 파랑, 오른쪽은 빨강.
    expect(b0, greaterThan(t0 * 0.95));
    expect(r0, 0);
    expect(r1, greaterThan(t1 * 0.95));
    expect(b1, 0);
  });
}
