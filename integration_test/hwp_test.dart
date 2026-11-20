// 앱과 함께 설치된 rhwp(<앱>/rhwp/rhwp.exe)를 실제로 돌리고 PDFium으로 결과를 읽는다. 실제 앱에서 돈다:
//   flutter test integration_test/hwp_test.dart -d windows
// 변환기가 없으면(third_party/rhwp/windows-x64/rhwp.exe를 안 넣었으면) 첫 시험이 converterMissing으로 실패한다.
import 'dart:io';

import 'package:daylight_pdf/convert/conversion_error.dart';
import 'package:daylight_pdf/convert/hwp_to_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

/// 시험 자료는 저장소의 `integration_test/fixtures/hwp/`(rhwp 저장소의 MIT 예제). 앱의 현재 폴더가 어디든 위로 올라가며 찾는다.
String _fixture(String name) {
  for (final start in [Directory.current.path, p.dirname(Platform.resolvedExecutable)]) {
    var dir = start;
    for (var i = 0; i < 10; i++) {
      final candidate = p.join(dir, 'integration_test', 'fixtures', 'hwp', name);
      if (File(candidate).existsSync()) return candidate;
      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }
  }
  throw StateError('시험 자료를 찾지 못했어요: $name');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('daylight_pdf_hwp_it'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('HWP → PDF: 쪽 수와 글자가 살아 있고 임시 파일이 남지 않는다', (tester) async {
    await pdfrxFlutterInitialize();
    final out = p.join(dir.path, 'biz_plan.pdf');
    final warnings = await tester.runAsync(() => HwpToPdf.convert(_fixture('biz_plan.hwp'), out));

    expect(File(out).existsSync(), isTrue);
    expect(File('$out.tmp').existsSync(), isFalse);
    for (final w in warnings!) {
      expect(w.kind, ConversionWarningKind.fontsSubstituted);
      expect(w.items, isNotEmpty);
      expect(w.items.every((n) => n.isNotEmpty && n.length <= 61), isTrue);
    }

    final document = await PdfDocument.openFile(out);
    addTearDown(document.dispose);
    expect(document.pages, hasLength(6));
    final text = (await document.pages.first.loadText())?.fullText ?? '';
    expect(text, contains('사업'), reason: '글자 추출이 되어야 한다(글꼴이 PDF에 제대로 들어갔다는 뜻)');
  });

  testWidgets('HWPX도 변환된다', (tester) async {
    await pdfrxFlutterInitialize();
    final out = p.join(dir.path, 'cellzone.pdf');
    await tester.runAsync(() => HwpToPdf.convert(_fixture('cellzone-merged-end-fill.hwpx'), out));
    final document = await PdfDocument.openFile(out);
    addTearDown(document.dispose);
    expect(document.pages, isNotEmpty);
  });

  testWidgets('HWP가 아닌 파일은 cannotRead이고 결과 파일을 남기지 않는다', (tester) async {
    final bad = p.join(dir.path, 'garbage.hwp');
    File(bad).writeAsStringSync('이건 HWP가 아니에요');
    final out = p.join(dir.path, 'garbage.pdf');
    // runAsync는 안에서 난 오류를 바로 테스트 오류로 올리므로 여기서 잡아 돌려준다.
    final error = await tester.runAsync(() async {
      try {
        await HwpToPdf.convert(bad, out);
        return null;
      } on ConversionException catch (e) {
        return e;
      }
    });
    expect(error, isNotNull, reason: '변환이 실패해야 한다');
    expect(error!.kind, ConversionErrorKind.cannotRead);
    expect(error.fileName, 'garbage.hwp');
    expect(File(out).existsSync(), isFalse);
    expect(File('$out.tmp').existsSync(), isFalse);
  });

  testWidgets('글꼴을 내려받지 않는다: 오프라인 캐시 폴더가 비어 있다', (tester) async {
    final cache = Directory(p.join(dir.path, 'font_cache'));
    final out = p.join(dir.path, 'offline.pdf');
    await tester.runAsync(() => HwpToPdf.convert(_fixture('biz_plan.hwp'), out, cacheDir: cache.path));
    expect(File(out).existsSync(), isTrue);
    final files = cache.existsSync() ? cache.listSync(recursive: true).whereType<File>().toList() : <File>[];
    expect(files, isEmpty, reason: '오프라인 모드면 CDN에서 받은 글꼴이 쌓이지 않는다');
  });
}
