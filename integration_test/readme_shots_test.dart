// README 스크린샷과 데모 GIF의 원본 화면을 만든다 (검사는 하지 않는다). 영어 UI, 1200x720, 라이트·다크:
//   flutter test integration_test/readme_shots_test.dart -d macos
// 결과는 시스템 임시 폴더의 `daylight_pdf_readme/`에 남는다. 다듬는 방법은 CLAUDE.md의 "README 스크린샷" 참고.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:daylight_pdf/convert/convert_screen.dart';
import 'package:daylight_pdf/engine/annotations/annotation_specs.dart';
import 'package:daylight_pdf/engine/annotations/pdfium_annotations.dart';
import 'package:daylight_pdf/home/home_screen.dart';
import 'package:daylight_pdf/print/print_dialog.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/pages/edit_tab.dart';
import 'package:daylight_pdf/pages/page_ops.dart';
import 'package:daylight_pdf/pages/page_tools_screen.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/theme/app_theme.dart';
import 'package:daylight_pdf/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => windowManager.ensureInitialized());

  testWidgets('readme shots', (tester) async {
    await pdfrxFlutterInitialize();
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final out = Directory('${Directory.systemTemp.path}/daylight_pdf_readme')..createSync(recursive: true);
    final work = Directory.systemTemp.createTempSync('daylight_pdf_readme_work');
    addTearDown(() => work.deleteSync(recursive: true));
    final shotKey = GlobalKey();

    // ---- 보여 주기용 자료 ----
    final fontBytes = (await rootBundle.load('assets/fonts/seoul_namsan_regular.ttf'));
    final boldBytes = (await rootBundle.load('assets/fonts/seoul_namsan_bold.ttf'));
    final regular = pw.Font.ttf(fontBytes), bold = pw.Font.ttf(boldBytes);
    const ink = pdf.PdfColor.fromInt(0xFF1F2937), accent = pdf.PdfColor.fromInt(0xFF4C9DFF);

    pw.Widget heading(String name, String title) => pw.Outline(
      name: name,
      title: title,
      level: 0,
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 8),
        child: pw.Text(
          title,
          style: pw.TextStyle(font: bold, fontSize: 22, color: ink),
        ),
      ),
    );
    pw.Widget body(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: regular, fontSize: 11.5, lineSpacing: 4, color: ink),
      ),
    );
    pw.Widget bar(String label, double value, pdf.PdfColor color) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 60,
            child: pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 10)),
          ),
          pw.Container(width: 300 * value, height: 14, color: color),
          pw.SizedBox(width: 6),
          pw.Text('${(value * 100).round()}%', style: pw.TextStyle(font: regular, fontSize: 10)),
        ],
      ),
    );

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Quarterly Report',
              style: pw.TextStyle(font: bold, fontSize: 30, color: accent),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Q3 · Product and growth review',
              style: pw.TextStyle(font: regular, fontSize: 13, color: ink),
            ),
            pw.SizedBox(height: 28),
            heading('summary', '1. Summary'),
            body(
              'Revenue grew 18% over the previous quarter, led by the new subscription tier. Churn fell to its lowest '
              'level in two years and support tickets per customer dropped by a third.',
            ),
            body('Three priorities for next quarter: onboarding, reliability, and a faster release cadence.'),
            pw.SizedBox(height: 18),
            pw.Text(
              'Highlights',
              style: pw.TextStyle(font: bold, fontSize: 14, color: ink),
            ),
            pw.SizedBox(height: 6),
            bar('Revenue', 0.78, accent),
            bar('Retention', 0.92, const pdf.PdfColor.fromInt(0xFF34D399)),
            bar('Support', 0.64, const pdf.PdfColor.fromInt(0xFFFB923C)),
            bar('Releases', 0.55, const pdf.PdfColor.fromInt(0xFF7C5CFF)),
          ],
        ),
      ),
    );
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            heading('revenue', '2. Revenue'),
            body(
              'Subscription revenue reached its highest level so far. Growth came mostly from existing teams moving '
              'to the annual plan, while new sign-ups stayed steady.',
            ),
            body('Average revenue per account rose 6%. Expansion revenue now makes up a quarter of the total.'),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: ['Plan', 'Accounts', 'Revenue'],
              data: [
                ['Free', '4,820', '—'],
                ['Team', '1,264', '\$38,900'],
                ['Business', '312', '\$61,400'],
              ],
              headerStyle: pw.TextStyle(font: bold, fontSize: 11),
              cellStyle: pw.TextStyle(font: regular, fontSize: 11),
              headerDecoration: const pw.BoxDecoration(color: pdf.PdfColor.fromInt(0xFFE5EEFF)),
            ),
          ],
        ),
      ),
    );
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            heading('outlook', '3. Outlook'),
            body('We expect steady growth next quarter. The main risks are hiring pace and a slower enterprise cycle.'),
            body('Decisions needed this month: pricing for the annual plan, and the scope of the mobile beta.'),
          ],
        ),
      ),
    );
    final reportPath = '${work.path}/Quarterly Report.pdf';
    File(reportPath).writeAsBytesSync(await doc.save());

    // 페이지 도구 화면용 12쪽 문서 (같은 3쪽을 되풀이)
    final longPath = '${work.path}/Annual Report.pdf';
    await tester.runAsync(() => PageOps.build([for (var i = 0; i < 12; i++) PageRef(reportPath, i % 3)], longPath));

    // 주석 달린 사본: 형광펜(글자 위치를 찾아서), 밑줄, 메모, 손글씨, 사각형
    final annotatedPath = '${work.path}/Quarterly Report (annotated).pdf';
    await tester.runAsync(() async {
      final d = await PdfDocument.openFile(reportPath);
      try {
        PdfBox boxOf(PdfPageTextRange r) =>
            (left: r.bounds.left, bottom: r.bounds.bottom, right: r.bounds.right, top: r.bounds.top);
        Future<List<PdfBox>> find(int pageIndex, String needle) async {
          final text = await d.pages[pageIndex].loadStructuredText();
          return [await for (final m in text.allMatches(needle, caseInsensitive: true)) boxOf(m)];
        }

        final growth = await find(0, 'Revenue grew 18%');
        final churn = await find(0, 'lowest level in two years');
        final record = await find(1, 'highest level so far');
        await PdfiumAnnotations.add(d, [
          if (growth.isNotEmpty) HighlightSpec(pageIndex: 0, color: 0xFFFFEB3B, boxes: growth),
          if (churn.isNotEmpty) UnderlineSpec(pageIndex: 0, color: 0xFFE53935, boxes: churn),
          if (record.isNotEmpty) HighlightSpec(pageIndex: 1, color: 0xFF43A047, boxes: record),
          const NoteSpec(pageIndex: 0, color: 0xFFFFEB3B, x: 470, y: 690, text: 'Check this number with finance.'),
          const ShapeSpec(
            pageIndex: 0,
            color: 0xFFE53935,
            kind: ShapeKind.circle,
            box: (left: 118, bottom: 408, right: 372, top: 440),
            width: 2,
          ),
          InkSpec(
            pageIndex: 1,
            color: 0xFF1E88E5,
            strokes: [
              [for (var i = 0; i <= 24; i++) (x: 330.0 + i * 8, y: 560.0 + (i.isEven ? 8 : -8) + (i * 1.5))],
            ],
          ),
        ]);
        File(annotatedPath).writeAsBytesSync(await d.encodePdf());
      } finally {
        d.dispose();
      }
    });

    // 변환 화면용 이미지
    final colors = [img.ColorRgb8(255, 196, 120), img.ColorRgb8(150, 200, 255), img.ColorRgb8(180, 230, 180)];
    final pngs = <String>[];
    for (var i = 0; i < 3; i++) {
      final im = img.Image(width: 600, height: 400)..clear(colors[i]);
      pngs.add('${work.path}/Photo ${i + 1}.png');
      File(pngs[i]).writeAsBytesSync(img.encodePng(im));
    }
    File('${work.path}/Logo.svg').writeAsStringSync(
      '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"><circle cx="100" cy="100" r="80" fill="#4C9DFF"/></svg>',
    );
    final recent = <String>[];
    for (final name in [
      'Quarterly Report',
      'Meeting notes',
      'Invoice 2026-041',
      'Design spec v3',
      'Travel itinerary',
    ]) {
      final f = File('${work.path}/$name.pdf')..writeAsBytesSync(File(reportPath).readAsBytesSync());
      recent.add(f.path);
    }

    // ---- 화면 찍기 ----
    Future<void> shoot(String name) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1800)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      File('${out.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
    }

    Future<void> pump(Widget home, ThemeMode mode, {Map<String, Object> prefs = const {}}) async {
      SharedPreferences.setMockInitialValues(prefs);
      final settings = await AppSettings.load();
      await tester.pumpWidget(
        RepaintBoundary(
          key: shotKey,
          child: AppSettingsScope(
            settings: settings,
            child: MaterialApp(
              key: UniqueKey(),
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(dense: true),
              darkTheme: AppTheme.dark(dense: true),
              themeMode: mode,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: home,
            ),
          ),
        ),
      );
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> alternate([int rounds = 5]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    // 변환이 만든 파일은 다음 테마에서 "(1)" 이름이 붙지 않게 지운다
    final inputs = {...pngs, '${work.path}/Logo.svg', reportPath, annotatedPath, longPath, ...recent};
    void cleanOutputs() {
      for (final e in work.listSync()) {
        if (!inputs.contains(e.path)) e.deleteSync(recursive: true);
      }
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final m = mode.name;
      cleanOutputs();
      await pump(HomeScreen(onAbout: () {}), mode, prefs: {'recent_files': recent});
      await shoot('home_$m');

      await pump(ConvertScreen(initialPaths: [pngs[0], pngs[1], pngs[2], '${work.path}/Logo.svg', reportPath]), mode);
      await shoot('convert_$m');

      // 보기: 주석이 달린 문서, 목차 탭, 검색 줄
      await pump(ViewerScreen(path: annotatedPath), mode);
      await tester.tap(find.text('Outline'));
      await tester.pump();
      await tester.tap(find.byTooltip('Fit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fit width'));
      await alternate(2);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.widgetWithText(TextField, ''), 'revenue');
      await tester.pump(const Duration(milliseconds: 700));
      await alternate();
      await shoot('viewer_$m');

      // 페이지 도구
      await pump(PageToolsScreen(initialPath: longPath), mode);
      await tester.tap(find.byType(PageTile).at(1));
      await tester.pump();
      await tester.tap(find.byType(PageTile).at(4));
      await tester.pump();
      await shoot('pages_$m');
    }

    // 인쇄 설정 창 (라이트): 한 장에 4쪽, 쪽 번호, 워터마크
    await pump(ViewerScreen(path: reportPath), ThemeMode.light);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump(const Duration(milliseconds: 300));
    await alternate(3);
    final list = find.descendant(
      of: find.descendant(of: find.byType(PrintDialog), matching: find.byType(ListView)).first,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text('4'), 150, scrollable: list.first);
    await tester.tap(find.text('4'));
    await alternate(3);
    await tester.drag(list.first, const Offset(0, 1200)); // 설정 목록을 맨 위로
    await alternate(2);
    await shoot('print_light');
  });
}
