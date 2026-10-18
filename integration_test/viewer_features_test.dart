// 실제 PDFium으로 보기 화면의 글자 검색, 목차, 암호 PDF, 보기 맞춤을 구동한다:
//   flutter test integration_test/viewer_features_test.dart -d macos
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' show md5;
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/viewer/search_bar.dart';
import 'package:daylight_pdf/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => windowManager.ensureInitialized());

  late Directory dir;
  setUp(() async {
    await pdfrxFlutterInitialize();
    dir = Directory.systemTemp.createTempSync('daylight_pdf_viewer_features');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpViewer(WidgetTester tester, String path) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ViewerScreen(key: ValueKey(path), path: path),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  /// 검색어를 바꾼 뒤: 0.5초 쉬었다 시작하는 검색, 화면 이동 애니메이션(프레임), 문서 읽기(실제 시간)를 번갈아 기다린다.
  Future<void> searchSettle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> settle(WidgetTester tester, [int ms = 1500]) async {
    await tester.pump(const Duration(milliseconds: 700)); // 검색은 입력 뒤 0.5초 쉬었다 시작한다
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// 대화상자가 닫히는 애니메이션(프레임이 필요)과 pdfrx의 비동기 작업(실제 시간이 필요)을 번갈아 기다린다.
  Future<void> alternate(WidgetTester tester, {int rounds = 4}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// 글자가 든 3쪽 PDF: 쪽마다 `apple`이 들어 있고 2쪽에는 `banana`도 있다. 목차(북마크) 3개.
  Future<String> makeTextPdf() async {
    final doc = pw.Document();
    for (var i = 1; i <= 3; i++) {
      doc.addPage(
        pw.Page(
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Outline(
                name: 'ch$i',
                title: 'Chapter $i',
                level: 0,
                child: pw.Text('Heading $i', style: const pw.TextStyle(fontSize: 28)),
              ),
              pw.Text('This page has an apple on it. Page number $i.'),
              if (i == 2) pw.Text('Only this page has a banana.'),
            ],
          ),
        ),
      );
    }
    final path = '${dir.path}/text.pdf';
    File(path).writeAsBytesSync(await doc.save());
    return path;
  }

  Finder inBar(String text) => find.descendant(of: find.byType(ViewerSearchBar), matching: find.text(text));

  testWidgets('text search counts matches, moves between them and closes with Esc', (tester) async {
    final path = await makeTextPdf();
    await pumpViewer(tester, path);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.search_rounded), findsWidgets);
    expect(find.text('PDF 안에서 찾기'), findsOneWidget, reason: 'search bar is open');

    await tester.enterText(find.widgetWithText(TextField, ''), 'apple');
    await searchSettle(tester);
    expect(inBar('1 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('다음 결과'));
    await alternate(tester, rounds: 3);
    expect(inBar('2 / 3'), findsOneWidget);
    await tester.tap(find.byTooltip('이전 결과'));
    await alternate(tester, rounds: 3);
    expect(inBar('1 / 3'), findsOneWidget);

    // 이동 단추를 눌러 입력칸의 초점이 빠졌으니 다시 눌러 초점을 준다
    await tester.tap(find.widgetWithText(TextField, 'apple'));
    await tester.enterText(find.widgetWithText(TextField, 'apple'), 'banana');
    await searchSettle(tester);
    expect(inBar('1 / 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextField, 'banana'));
    await tester.enterText(find.widgetWithText(TextField, 'banana'), 'zzzz');
    await searchSettle(tester);
    expect(inBar('찾지 못했어요'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PDF 안에서 찾기'), findsNothing, reason: 'Esc closes the search bar');
  });

  testWidgets('the outline tab lists the bookmarks and jumps to a chapter', (tester) async {
    final path = await makeTextPdf();
    await pumpViewer(tester, path);
    await settle(tester, 800);
    expect(find.text('목차'), findsOneWidget, reason: 'the outline tab appears when the PDF has bookmarks');
    await tester.tap(find.text('목차'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Chapter 3'), findsOneWidget);
    await tester.tap(find.text('Chapter 3'));
    await settle(tester, 800);
    expect(find.text('3 / 3'), findsOneWidget, reason: 'jumped to page 3');
    // 쪽 탭으로 돌아오면 썸네일이 다시 보인다
    await tester.tap(find.text('쪽'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 3'), findsNothing);
  });

  /// 표준 보안 핸들러(RC4 40비트, V1/R2)로 암호를 건 PDF를 만든다. `pdf` 패키지에는 암호화가 없다.
  Uint8List encryptedPdf({required String userPassword}) {
    final pad = Uint8List.fromList([
      0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
      0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80, 0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A, //
    ]);
    Uint8List padded(String pw) {
      final b = [...pw.codeUnits, ...pad];
      return Uint8List.fromList(b.sublist(0, 32));
    }

    Uint8List rc4(List<int> key, List<int> data) {
      final s = List<int>.generate(256, (i) => i);
      var j = 0;
      for (var i = 0; i < 256; i++) {
        j = (j + s[i] + key[i % key.length]) & 255;
        final t = s[i];
        s[i] = s[j];
        s[j] = t;
      }
      final out = Uint8List(data.length);
      var a = 0, b = 0;
      for (var n = 0; n < data.length; n++) {
        a = (a + 1) & 255;
        b = (b + s[a]) & 255;
        final t = s[a];
        s[a] = s[b];
        s[b] = t;
        out[n] = data[n] ^ s[(s[a] + s[b]) & 255];
      }
      return out;
    }

    final id = Uint8List.fromList(List<int>.generate(16, (i) => i * 7 + 3));
    const permissions = -4; // 모두 허용
    final ownerKey = md5.convert(padded('owner-secret')).bytes.sublist(0, 5);
    final o = rc4(ownerKey, padded(userPassword));
    final p = ByteData(4)..setInt32(0, permissions, Endian.little);
    final key = md5.convert([...padded(userPassword), ...o, ...p.buffer.asUint8List(), ...id]).bytes.sublist(0, 5);
    final u = rc4(key, pad);
    Uint8List objectKey(int n) {
      final k = [...key, n & 255, (n >> 8) & 255, (n >> 16) & 255, 0, 0];
      return Uint8List.fromList(md5.convert(k).bytes.sublist(0, 10));
    }

    String hex(List<int> b) => '<${b.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}>';
    final content = rc4(objectKey(4), 'BT /F1 24 Tf 20 100 Td (Secret apple) Tj ET'.codeUnits);
    final out = BytesBuilder();
    final offsets = <int>[];
    void add(List<int> b) => out.add(b);
    void obj(int n, String body, {List<int>? stream}) {
      offsets.add(out.length);
      add('$n 0 obj\n$body'.codeUnits);
      if (stream != null) {
        add('\nstream\n'.codeUnits);
        add(stream);
        add('\nendstream'.codeUnits);
      }
      add('\nendobj\n'.codeUnits);
    }

    add('%PDF-1.4\n'.codeUnits);
    obj(1, '<< /Type /Catalog /Pages 2 0 R >>');
    obj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    obj(
      3,
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    );
    obj(4, '<< /Length ${content.length} >>', stream: content);
    obj(5, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
    obj(6, '<< /Filter /Standard /V 1 /R 2 /O ${hex(o)} /U ${hex(u)} /P $permissions >>');
    final xref = out.length;
    add('xref\n0 7\n0000000000 65535 f \n'.codeUnits);
    for (final o in offsets) {
      add('${o.toString().padLeft(10, '0')} 00000 n \n'.codeUnits);
    }
    add(
      'trailer\n<< /Size 7 /Root 1 0 R /Encrypt 6 0 R /ID [${hex(id)} ${hex(id)}] >>\nstartxref\n$xref\n%%EOF\n'
          .codeUnits,
    );
    return out.toBytes();
  }

  testWidgets('a password protected PDF asks for the password, rejects a wrong one and opens with the right one', (
    tester,
  ) async {
    final path = '${dir.path}/locked.pdf';
    File(path).writeAsBytesSync(encryptedPdf(userPassword: 'open-sesame'));
    await pumpViewer(tester, path);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('암호가 필요해요'), findsOneWidget);
    expect(find.text('암호가 맞지 않아요. 다시 입력해 주세요.'), findsNothing);

    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.pump(); // 입력이 반영돼 단추가 켜진 뒤에 누른다
    await tester.tap(find.text('열기'));
    await alternate(tester, rounds: 8);
    expect(find.text('암호가 맞지 않아요. 다시 입력해 주세요.'), findsOneWidget, reason: 'asked again with a hint');

    await tester.enterText(find.byType(TextField), 'open-sesame');
    await tester.pump();
    await tester.tap(find.text('열기'));
    await alternate(tester);
    expect(find.text('암호가 필요해요'), findsNothing);
    expect(find.text('1 / 1'), findsOneWidget, reason: 'the document opened');
  });

  testWidgets('cancelling the password prompt shows a clear message instead of a blank page', (tester) async {
    final path = '${dir.path}/locked2.pdf';
    File(path).writeAsBytesSync(encryptedPdf(userPassword: 'pw'));
    await pumpViewer(tester, path);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('취소'));
    await alternate(tester);
    expect(find.textContaining('암호'), findsWidgets);
    expect(find.text('암호가 필요해요'), findsNothing);
  });

  /// 화면에서 쪽(순백 바탕)이 차지한 영역의 가로 길이.
  Future<double> pageWidth(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump();
    final viewer = tester.getRect(find.byType(PdfViewer));
    RenderObject? node = tester.renderObject(find.byType(PdfViewer));
    while (node != null && node is! RenderRepaintBoundary) {
      node = node.parent;
    }
    final image = await (node! as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    final y = (viewer.top + viewer.height / 2).toInt();
    var left = 1 << 30, right = -1;
    for (var x = viewer.left.toInt(); x < viewer.right.toInt(); x++) {
      final i = (y * image.width + x) * 4;
      if (rgba[i] == 255 && rgba[i + 1] == 255 && rgba[i + 2] == 255) {
        if (x < left) left = x;
        if (x > right) right = x;
      }
    }
    return (right - left + 1).toDouble();
  }

  testWidgets('the fit menu: actual size, fit width and fit page change the page size on screen', (tester) async {
    final path = await makeTextPdf(); // A4 595 x 842
    await pumpViewer(tester, path);
    final viewer = tester.getRect(find.byType(PdfViewer));

    Future<void> choose(String label) async {
      await tester.tap(find.byTooltip('보기 맞춤'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
    }

    await choose('실제 크기 (100%)');
    final actual = await pageWidth(tester);
    expect(actual, closeTo(595, 6), reason: '100% = the page is 595 logical pixels wide');

    await choose('너비에 맞춤');
    final fitWidth = await pageWidth(tester);
    expect(fitWidth, greaterThan(viewer.width - 60));
    expect(fitWidth, lessThanOrEqualTo(viewer.width));

    await choose('쪽에 맞춤');
    final fitPage = await pageWidth(tester);
    final byHeight = (viewer.height - 40) * 595 / 842;
    expect(fitPage, closeTo(byHeight, 40), reason: 'the whole page height fits in the view');
    expect(fitPage, lessThan(fitWidth));
  });
}
