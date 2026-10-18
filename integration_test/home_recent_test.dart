// 실제 PDFium으로 최근 파일 → 보기 → 돌아오기를 확인한다:
//   flutter test integration_test/home_recent_test.dart -d macos
import 'dart:io';

import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/home/home_screen.dart';
import 'package:daylight_pdf/home/recent_files.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
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

  testWidgets('opening a recent file shows it and moves it to the front of the list', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_home_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/p.png')
        .writeAsBytesSync(img.encodePng(img.Image(width: 200, height: 100)..clear(img.ColorRgb8(255, 255, 255))));
    for (final name in ['a', 'b']) {
      await ImageToPdf.convert(['${dir.path}/p.png'], '${dir.path}/$name.pdf');
    }
    // 최신순: b가 맨 앞
    SharedPreferences.setMockInitialValues({
      'recent_files': ['${dir.path}/b.pdf', '${dir.path}/a.pdf'],
    });
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(onAbout: () {}, recents: RecentFiles()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    List<String?> order() =>
        tester.widgetList<Text>(find.textContaining(RegExp(r'^[ab]\.pdf$'))).map((t) => t.data).toList();
    expect(order(), ['b.pdf', 'a.pdf']);

    await tester.tap(find.text('a.pdf'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(ViewerScreen), findsOneWidget, reason: 'tapping a recent file opens it');
    expect(await RecentFiles().load(), [
      '${dir.path}/a.pdf',
      '${dir.path}/b.pdf',
    ], reason: 'opened file moves up at once');

    await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsNothing);
    expect(order(), ['a.pdf', 'b.pdf'], reason: 'the list is refreshed when coming back');
  });
}
