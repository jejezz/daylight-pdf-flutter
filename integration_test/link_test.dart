// 실제 PDFium으로 PDF 링크를 확인한다:
//   flutter test integration_test/link_test.dart -d windows
import 'dart:io';

import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/viewer/viewer_screen.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf/pdf.dart' show PdfColors;
import 'package:pdf/widgets.dart' as pw show Anchor, Container, Document, Link, Page, Text, UrlLink, Widget;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// 1쪽은 3쪽으로 가는 내부 링크, 2쪽은 웹 주소 링크가 쪽 대부분을 덮는다.
Future<String> _makePdf(Directory dir) async {
  final doc = pw.Document();
  pw.Widget area() => pw.Container(width: 400, height: 600, color: PdfColors.grey200);
  doc.addPage(pw.Page(build: (_) => pw.Link(destination: 'target', child: area())));
  doc.addPage(pw.Page(build: (_) => pw.UrlLink(destination: 'https://example.com/hello', child: area())));
  doc.addPage(pw.Page(build: (_) => pw.Anchor(name: 'target', child: pw.Text('target page'))));
  final path = '${dir.path}/links.pdf';
  File(path).writeAsBytesSync(await doc.save());
  return path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => windowManager.ensureInitialized());

  testWidgets('links are read from the PDF, and tapping them navigates or asks before opening', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_link');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = await _makePdf(dir);

    // 링크가 PDF에서 제대로 읽히는지.
    final doc = await PdfDocument.openFile(path);
    final first = await doc.pages[0].loadLinks(compact: true);
    final second = await doc.pages[1].loadLinks(compact: true);
    expect(first.single.dest?.pageNumber, 3);
    expect(second.single.url, Uri.parse('https://example.com/hello'));
    await doc.dispose();

    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ViewerScreen(path: path),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    await settle();
    expect(find.text('1 / 3'), findsOneWidget);

    // 1쪽 링크는 보이는 쪽의 가운데쯤. 마우스를 올리면 손가락 커서.
    final center = tester.getCenter(find.byType(PdfViewer));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 7);
    await mouse.addPointer(location: center);
    await mouse.moveTo(center + const Offset(1, 1));
    await settle();
    await mouse.moveTo(center);
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(7),
      SystemMouseCursors.click,
    );

    // 누르면 3쪽으로 이동한다.
    await mouse.down(center);
    await mouse.up();
    await settle();
    expect(find.text('3 / 3'), findsOneWidget);
  });
}
