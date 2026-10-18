// 실제 PDFium으로 인쇄 설정 창을 구동한다:
//   flutter test integration_test/print_ui_test.dart -d macos
import 'dart:io';

import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/print/print_dialog.dart';
import 'package:daylight_pdf/print/print_options.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => windowManager.ensureInitialized());

  late Directory dir;
  late String pdfPath;

  setUp(() async {
    await pdfrxFlutterInitialize();
    dir = Directory.systemTemp.createTempSync('daylight_pdf_print_ui');
    final inputs = <String>[];
    for (var i = 0; i < 5; i++) {
      final path = '${dir.path}/p$i.png';
      File(path).writeAsBytesSync(
        img.encodePng(img.Image(width: 200, height: 300)..clear(img.ColorRgb8(60 + i * 30, 120, 200))),
      );
      inputs.add(path);
    }
    pdfPath = '${dir.path}/doc.pdf';
    await ImageToPdf.convert(inputs, pdfPath);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  /// 입력 뒤 쉬었다 가공하는 시간(0.3초)과 PDFium이 가공하는 시간을 기다린다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('Cmd+P in the viewer opens the print settings with the page count', (tester) async {
    await pumpApp(tester, ViewerScreen(path: pdfPath));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('인쇄'), findsWidgets);
    expect(find.text('5쪽 인쇄'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('5쪽 인쇄'), findsNothing);

    // 도구 줄의 인쇄 단추로도 열린다
    await tester.tap(find.byIcon(Icons.print_outlined).first);
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('5쪽 인쇄'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await settle(tester); // 닫을 때 미리보기 뷰어가 아직 쪽을 배치하는 중이면 pdfrx가 늦게 오류를 낸다
  });

  testWidgets('range, odd/even and a bad range are reflected, and the chosen options reach the system print', (
    tester,
  ) async {
    final bytes = Uint8List.fromList(await File(pdfPath).readAsBytes());
    PrintOptions? got;
    int? gotCurrent;
    var cancelNext = true; // 처음에는 운영체제 인쇄 창에서 취소한 것처럼
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: SizedBox(
                  width: 980,
                  height: 640,
                  child: PrintDialog(
                    pdfBytes: bytes,
                    pageCount: 5,
                    currentPage: 3,
                    jobName: 'test',
                    openSystemPrint: (options, pdf, current, name) async {
                      got = options;
                      gotCurrent = current;
                      return !cancelNext;
                    },
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await settle(tester);
    expect(find.text('5쪽 인쇄'), findsOneWidget);

    await tester.tap(find.text('쪽 지정'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '9');
    await settle(tester);
    expect(find.textContaining('쪽 범위'), findsWidgets); // 오류 문구
    expect(
      tester
          .widget<FilledButton>(find.ancestor(of: find.text('인쇄 창 열기'), matching: find.byType(FilledButton)))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), '2-5');
    await settle(tester);
    expect(find.text('4쪽 인쇄'), findsOneWidget);

    await tester.tap(find.text('홀수 쪽'));
    await settle(tester);
    expect(find.text('2쪽 인쇄'), findsOneWidget); // 3, 5

    await tester.tap(find.text('현재 쪽'));
    await settle(tester);
    expect(find.text('1쪽 인쇄'), findsOneWidget); // 현재 쪽 = 3쪽, 홀수라서 남는다

    await tester.tap(find.text('인쇄 창 열기'));
    await tester.pumpAndSettle();
    expect(got, isNotNull);
    expect(find.text('1쪽 인쇄'), findsOneWidget, reason: 'cancelling the system window keeps the settings window open');
    got = null;
    cancelNext = false;
    await tester.tap(find.text('인쇄 창 열기'));
    await tester.pumpAndSettle();
    expect(got, isNotNull);
    expect(got!.range, 'current');
    expect(got!.parity, PrintParity.odd);
    expect(gotCurrent, 3);
    expect(find.text('1쪽 인쇄'), findsNothing, reason: 'the dialog closes after handing over to the system print window');
    await settle(tester);
  });

  testWidgets(
    'N-up, booklet, page numbers, watermark and grayscale are chosen in the dialog and reach the system print',
    (tester) async {
      final bytes = await File(pdfPath).readAsBytes();
      PrintOptions? got;
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: SizedBox(
                    width: 980,
                    height: 640,
                    child: PrintDialog(
                      pdfBytes: bytes,
                      pageCount: 5,
                      currentPage: 1,
                      jobName: 'test',
                      openSystemPrint: (options, pdf, current, name) async {
                        got = options;
                        return true;
                      },
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await settle(tester);

      // 설정 목록은 길어서 아래쪽 항목은 스크롤해야 만들어진다
      final list = find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable));
      Future<void> show(String text) async {
        await tester.scrollUntilVisible(find.text(text), 150, scrollable: list.first);
        await tester.pump();
      }

      await show('4쪽');
      await tester.tap(find.text('4쪽'));
      await settle(tester);
      await show('쪽마다 테두리 그리기');
      await tester.tap(find.text('쪽마다 테두리 그리기'));
      await settle(tester);

      await show('소책자 (접어서 철하기)');
      await tester.tap(find.text('소책자 (접어서 철하기)'));
      await settle(tester);
      expect(find.textContaining('4의 배수'), findsOneWidget, reason: 'booklet hint');
      await tester.tap(find.text('소책자 (접어서 철하기)'));
      await settle(tester);

      await show('쪽 번호');
      await tester.tap(find.byType(DropdownButton<PrintPageNumbers>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('아래 가운데').last);
      await settle(tester);
      await show('전체 쪽수와 함께 (3 / 12)');
      await tester.tap(find.text('전체 쪽수와 함께 (3 / 12)'));
      await settle(tester);

      await show('워터마크 글자');
      await tester.enterText(find.widgetWithText(TextField, '').last, '사본');
      await settle(tester);
      await show('흑백으로 확실히 찍기');
      await tester.tap(find.text('흑백으로 확실히 찍기'));
      await settle(tester);

      await tester.tap(find.text('인쇄 창 열기'));
      await tester.pumpAndSettle();
      final o = got!;
      expect(o.perSheet, 4);
      expect(o.booklet, isFalse);
      expect(o.sheetBorder, isTrue);
      expect(o.pageNumbers, PrintPageNumbers.bottomCenter);
      expect(o.pageNumberTotal, isTrue);
      expect(o.watermark, '사본');
      expect(o.grayscale, isTrue);
      await settle(tester);
    },
  );
}
