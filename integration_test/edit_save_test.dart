// 편집 탭에서 쪽을 옮겨 저장하는 흐름을 실제 PDFium으로 본다 (같은 이름으로 덮어쓰기, 용량, 다른 곳이 파일을 열어 둔 경우):
//   flutter test integration_test/edit_save_test.dart -d windows
import 'dart:io';

import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/pages/edit_tab.dart';
import 'package:daylight_pdf/platform/new_window.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/viewer/viewer_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'raw_pdf.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 보기 화면의 앱 바(FocusTint)가 window_manager를 부른다.
  setUpAll(() => windowManager.ensureInitialized());

  late Directory dir;
  late String pdf;
  setUp(() async {
    await pdfrxFlutterInitialize();
    dir = Directory.systemTemp.createTempSync('daylight_pdf_edit_save');
    pdf = '${dir.path}/doc.pdf';
    File(pdf).writeAsBytesSync(sharedImagePdf(pages: 6));
  });
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows는 PDFium이 아직 쥔 파일을 지우지 못할 수 있다. 임시 폴더라 둔다.
    }
  });

  Future<void> show(WidgetTester tester, String target) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditTab(initialPath: pdf, savePicker: (l10n, {required suggestedName, initialDirectory}) async => target),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  /// 1쪽 카드를 4쪽 카드 위로 끌어 옮긴다.
  Future<void> moveFirstPage(WidgetTester tester) async {
    final from = tester.getCenter(find.byType(PageTile).at(0));
    final to = tester.getCenter(find.byType(PageTile).at(3));
    final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  Future<void> save(WidgetTester tester, {int rounds = 20}) async {
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    // 파일 쓰기와 다시 열기는 실제 시간이 걸린다.
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (rounds >= 20) await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testWidgets('moving a page and saving under another name keeps the size', (tester) async {
    await show(tester, '${dir.path}/other.pdf');
    await moveFirstPage(tester);
    await save(tester);
    final original = File(pdf).lengthSync(), saved = File('${dir.path}/other.pdf').lengthSync();
    expect(saved, lessThan(original * 1.5), reason: 'original=$original saved=$saved');
    final doc = await PdfDocument.openFile('${dir.path}/other.pdf');
    expect(doc.pages.length, 6);
    doc.dispose();
  });

  testWidgets('moving a page and saving over the same file replaces it, and the tab survives leaving', (tester) async {
    await show(tester, pdf);
    await moveFirstPage(tester);
    final before = File(pdf).lengthSync();
    await save(tester);
    expect(File('$pdf.tmp').existsSync(), isFalse);
    expect(File(pdf).lengthSync(), lessThan(before * 1.5));
    // 덮어쓴 파일을 다시 읽어 와서 6쪽이 그대로 보인다.
    expect(find.byType(PageTile), findsNWidgets(6));
    // 화면을 떠난다(뒤로 가기).
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('back'))));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump();
    expect(find.text('back'), findsOneWidget);
  });

  testWidgets('saving over a file another screen still has open fails with a message and keeps the original', (tester) async {
    // 보기 화면이 같은 파일을 열어 둔 것과 같은 상황.
    final holder = await PdfDocument.openFile(pdf);
    addTearDown(holder.dispose);
    await show(tester, pdf);
    await moveFirstPage(tester);
    final before = File(pdf).readAsBytesSync();
    await save(tester, rounds: 10); // 안내(스낵바)가 사라지기 전에 본다
    expect(File(pdf).readAsBytesSync(), before, reason: 'the original stays intact');
    expect(File('$pdf.tmp').existsSync(), isFalse);
    expect(find.textContaining('다른 이름으로 저장하세요'), findsOneWidget, reason: 'the user is told what to do');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the saved message has an Open button that shows the saved file in the viewer', (tester) async {
    final target = '${dir.path}/other.pdf';
    await show(tester, target);
    await moveFirstPage(tester);
    await save(tester, rounds: 10);
    expect(find.textContaining('저장했어요'), findsOneWidget);
    final launched = <String>[];
    newWindowLauncherForTest = (path) async {
      launched.add(path);
      return true;
    };
    addTearDown(() => newWindowLauncherForTest = null);
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    // 데스크톱은 새 창(새 프로세스)에서 연다: 이 창은 그대로이고 보기 화면으로 가지 않는다.
    expect(launched, [target]);
    expect(find.byType(ViewerScreen), findsNothing);
  });

  testWidgets('when the new window cannot start, Open falls back to the viewer in this window', (tester) async {
    final target = '${dir.path}/other.pdf';
    await show(tester, target);
    await moveFirstPage(tester);
    await save(tester, rounds: 10);
    newWindowLauncherForTest = (path) async => false;
    addTearDown(() => newWindowLauncherForTest = null);
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<ViewerScreen>(find.byType(ViewerScreen)).path, target);
  });

  testWidgets('overwriting the file the viewer has open works: the viewer lets go, then reloads the new content', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ViewerScreen(path: pdf),
        ),
      ),
    );
    Future<void> settle([int ms = 1500]) async {
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
      await tester.pump(const Duration(milliseconds: 200));
    }

    await settle(2500);
    final before = File(pdf).readAsBytesSync();
    EditTab.savePickerOverride = (l10n, {required suggestedName, initialDirectory}) async => pdf;
    addTearDown(() => EditTab.savePickerOverride = null);

    await tester.tap(find.byTooltip('페이지 편집'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await settle(1500);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await moveFirstPage(tester);
    await save(tester, rounds: 10);

    expect(File(pdf).readAsBytesSync(), isNot(before), reason: 'the file under the open viewer was replaced');
    expect(File('$pdf.tmp').existsSync(), isFalse);
    expect(find.textContaining('저장했어요'), findsOneWidget);
    expect(find.text('열기'), findsNothing, reason: 'the viewer reloads by itself, no second window needed');

    // 뒤로 가면 보기 화면이 새 내용으로 다시 열려 있다.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await settle(2500);
    expect(tester.takeException(), isNull);
    expect(find.byType(PdfViewer), findsOneWidget);
    final viewerPdf = tester.widget<PdfViewer>(find.byType(PdfViewer));
    expect(viewerPdf.documentRef, isNotNull);
  });
}
