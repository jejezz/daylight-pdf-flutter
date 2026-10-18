// 실제 PDFium으로 북마크 달기·이동·지우기를 확인한다:
//   flutter test integration_test/bookmark_test.dart -d macos
import 'dart:io';

import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/viewer/bookmarks.dart';
import 'package:daylight_pdf/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => windowManager.ensureInitialized());

  testWidgets('bookmark the current page, jump to it from the sidebar, and remove it', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_bookmark');
    addTearDown(() => dir.deleteSync(recursive: true));
    final inputs = <String>[];
    for (var i = 0; i < 3; i++) {
      final page = img.Image(width: 400, height: 800)..clear(img.ColorRgb8(240, 240, 240 - i * 30));
      inputs.add('${dir.path}/p$i.png');
      File(inputs[i]).writeAsBytesSync(img.encodePng(page));
    }
    final path = '${dir.path}/doc.pdf';
    await ImageToPdf.convert(inputs, path);

    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    Future<void> open() async {
      await tester.pumpWidget(
        AppSettingsScope(
          settings: settings,
          child: MaterialApp(
            key: UniqueKey(),
            locale: const Locale('ko'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ViewerScreen(path: path),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    await open();
    expect(find.byTooltip(RegExp('이 쪽에 북마크')), findsOneWidget);

    await tester.tap(find.byTooltip(RegExp('이 쪽에 북마크')));
    await tester.pumpAndSettle();
    expect(find.byTooltip(RegExp('북마크 지우기 \\(')), findsOneWidget, reason: 'the button shows the page is marked');
    expect(await BookmarkStore().load(path), [1]);

    // 다시 열어도 남아 있고, 사이드바 "북마크"에서 보인다
    await open();
    expect(find.byTooltip(RegExp('북마크 지우기 \\(')), findsOneWidget);
    await tester.tap(find.text('북마크'));
    await tester.pumpAndSettle();
    expect(find.text('1쪽'), findsOneWidget);

    // 3쪽에 하나 더 달고, 목록에서 1쪽을 지운다
    await BookmarkStore().toggle(path, 3);
    await open();
    await tester.tap(find.text('북마크'));
    await tester.pumpAndSettle();
    expect(find.text('3쪽'), findsOneWidget);
    await tester.tap(find.text('3쪽'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('북마크 지우기').first);
    await tester.pumpAndSettle();
    expect(await BookmarkStore().load(path), [3]);
    expect(find.text('1쪽'), findsNothing);
  });
}
