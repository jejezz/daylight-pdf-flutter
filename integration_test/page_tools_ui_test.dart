// 실제 PDFium으로 화면을 구동한다:
//   flutter test integration_test/page_tools_ui_test.dart -d macos
import 'dart:io';

import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/pages/page_tools_screen.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 앱 바의 FocusTint가 window_manager를 부른다. 실제 앱은 main()에서 하는 초기화를 여기서도 한다.
  setUpAll(() => windowManager.ensureInitialized());

  testWidgets('edit tab: select, delete, rotate and reset pages of a real PDF', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_ui');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pngs = <String>[];
    for (var i = 0; i < 3; i++) {
      pngs.add('${dir.path}/$i.png');
      File(pngs[i]).writeAsBytesSync(img.encodePng(img.Image(width: 100 + i * 10, height: 50)));
    }
    await ImageToPdf.convert(pngs, '${dir.path}/doc.pdf');

    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PageToolsScreen(initialPath: '${dir.path}/doc.pdf'),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    expect(find.text('1쪽'), findsOneWidget);
    expect(find.text('3쪽'), findsOneWidget);

    // 아무것도 고르지 않고 삭제하면 안내만 나온다.
    await tester.tap(find.byTooltip('선택한 쪽 삭제'));
    await tester.pump();
    expect(find.text('먼저 쪽을 선택하세요'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(3));

    // 첫 쪽을 골라 지우면 2쪽이 남고 번호가 다시 매겨진다.
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    expect(find.text('1쪽 선택'), findsOneWidget);
    await tester.tap(find.byTooltip('선택한 쪽 삭제'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(find.text('3쪽'), findsNothing);

    // 모두 골라 돌려도 화면이 무너지지 않고, 되돌리면 3쪽으로 돌아온다.
    await tester.tap(find.byTooltip('모두 선택'));
    await tester.pump();
    await tester.tap(find.byTooltip('오른쪽으로 회전'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    await tester.tap(find.byTooltip('되돌리기'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    expect(tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).every((t) => !t.value!), isTrue);
  });

  testWidgets('edit tab reports a file that cannot be opened', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_ui');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/fake.pdf').writeAsStringSync('not a pdf');

    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PageToolsScreen(initialPath: '${dir.path}/fake.pdf'),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text("Couldn't read the file: fake.pdf"), findsOneWidget);
    expect(find.text('Open or drop a PDF to edit'), findsOneWidget);
  });
}
