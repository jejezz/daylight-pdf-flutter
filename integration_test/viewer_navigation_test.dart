// 실제 PDFium으로 보기 화면의 쪽 이동을 확인한다:
//   flutter test integration_test/viewer_navigation_test.dart -d macos
import 'dart:io';
import 'dart:ui' as ui;

import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/viewer/viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => windowManager.ensureInitialized());

  testWidgets('every page, including the last one, opens at its top when picked in the sidebar', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_nav');
    addTearDown(() => dir.deleteSync(recursive: true));

    // 세로로 긴 쪽 3장: 위 80px는 빨강, 아래 80px는 파랑 (어느 부분이 보이는지 색으로 안다). 쪽마다 바탕색이 다르다.
    final inputs = <String>[];
    for (var i = 0; i < 3; i++) {
      final page = img.Image(width: 400, height: 800)..clear(img.ColorRgb8(230, 230, 230 - i * 30));
      img.fillRect(page, x1: 0, y1: 0, x2: 399, y2: 79, color: img.ColorRgb8(220, 20, 20));
      img.fillRect(page, x1: 0, y1: 720, x2: 399, y2: 799, color: img.ColorRgb8(20, 20, 220));
      inputs.add('${dir.path}/p$i.png');
      File(inputs[i]).writeAsBytesSync(img.encodePng(page));
    }
    await ImageToPdf.convert(inputs, '${dir.path}/doc.pdf');

    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ViewerScreen(path: '${dir.path}/doc.pdf'),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    Future<({int w, List<int> rgba})> capture() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500))); // 쪽 이미지가 그려질 시간
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      RenderObject? node = tester.renderObject(find.byType(PdfViewer));
      while (node != null && node is! RenderRepaintBoundary) {
        node = node.parent;
      }
      final image = await (node! as RenderRepaintBoundary).toImage(pixelRatio: 1);
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return (w: image.width, rgba: data.buffer.asUint8List());
    }

    String colorAt(({int w, List<int> rgba}) shot, Offset p) {
      final i = (p.dy.toInt() * shot.w + p.dx.toInt()) * 4;
      final r = shot.rgba[i], g = shot.rgba[i + 1], b = shot.rgba[i + 2];
      if (r > 180 && g < 80 && b < 80) return 'red';
      if (b > 180 && r < 80 && g < 80) return 'blue';
      return 'other';
    }

    /// 실패했을 때 눈으로 볼 수 있게 화면을 PNG로 남긴다 (시스템 임시 폴더).
    Future<void> dump(WidgetTester t, String name) async {
      RenderObject? node = t.renderObject(find.byType(PdfViewer));
      while (node != null && node is! RenderRepaintBoundary) {
        node = node.parent;
      }
      final image = await (node! as RenderRepaintBoundary).toImage(pixelRatio: 1);
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      File('${Directory.systemTemp.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
    }

    final viewer = tester.getRect(find.byType(PdfViewer));
    final cx = viewer.center.dx;
    final nearBottom = Offset(cx, viewer.bottom - 30);

    /// 뷰어 배경과 뚜렷이 다른 첫 줄 = 쪽이 시작하는 줄 (쪽 위 여백과 그림자에 상관없이 찾는다).
    Offset pageTopProbe(({int w, List<int> rgba}) shot) {
      int ch(int y, int c) => shot.rgba[(y * shot.w + cx.toInt()) * 4 + c];
      final y0 = viewer.top.toInt() + 2;
      for (var y = y0 + 1; y < viewer.bottom.toInt(); y++) {
        final differs = [0, 1, 2].any((c) => (ch(y, c) - ch(y0, c)).abs() > 60);
        if (differs) return Offset(cx, y + 20.0); // 쪽의 첫 줄에서 20픽셀 안쪽
      }
      return Offset(cx, viewer.top + 30);
    }

    for (final page in [2, 3, 1]) {
      await tester.tap(find.text('$page')); // 사이드바 썸네일의 쪽 번호
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      final shot = await capture();
      await dump(tester, 'daylight_pdf_nav_page$page');
      expect(
        colorAt(shot, pageTopProbe(shot)),
        'red',
        reason: 'page $page must open at its top (the red band is the top of a page)',
      );
      expect(colorAt(shot, nearBottom), isNot('blue'), reason: 'page $page must not be scrolled to its bottom');
    }
  });
}
