// 실제 PDFium으로 왼쪽 사이드바 너비 조절을 확인한다:
//   flutter test integration_test/sidebar_resize_test.dart -d macos
import 'dart:io';

import 'package:daylight_pdf/convert/image_to_pdf.dart';
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

  testWidgets('dragging the sidebar edge changes its width, within limits, and is remembered', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_sidebar');
    addTearDown(() => dir.deleteSync(recursive: true));
    final png = '${dir.path}/p.png';
    File(png).writeAsBytesSync(img.encodePng(img.Image(width: 400, height: 800)..clear(img.ColorRgb8(240, 240, 240))));
    final path = '${dir.path}/doc.pdf';
    await ImageToPdf.convert([png, png], path);

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

    double sidebarWidth() => tester.getTopLeft(find.byType(PdfViewer)).dx;
    final handle = find.byWidgetPredicate((w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn);

    await open();
    expect(sidebarWidth(), 148);

    await tester.drag(handle, const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(sidebarWidth(), 248);

    await tester.drag(handle, const Offset(2000, 0)); // 너무 멀리 끌어도 상한에서 멈춘다
    await tester.pumpAndSettle();
    expect(sidebarWidth(), lessThanOrEqualTo(480));
    expect(sidebarWidth(), greaterThan(300));

    await tester.drag(handle, const Offset(-2000, 0)); // 하한
    await tester.pumpAndSettle();
    expect(sidebarWidth(), 148);

    await tester.drag(handle, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(sidebarWidth(), 208);

    await open(); // 다시 열어도 같은 너비
    await tester.pumpAndSettle();
    expect(sidebarWidth(), 208);

    // 북마크 탭으로 바꿔도 사용자가 정한 너비를 지킨다
    await tester.tap(find.text('북마크'));
    await tester.pumpAndSettle();
    expect(sidebarWidth(), 208);
  });
}
