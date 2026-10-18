// 실제 PDFium과 뷰어로 터치·펜 그리기를 확인한다:
//   flutter test integration_test/touch_draw_test.dart -d macos
import 'dart:io';
import 'dart:ui' as ui;

import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/viewer/viewer_screen.dart';
import 'package:flutter/gestures.dart';
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

  late Directory dir;
  late String path;

  setUp(() async {
    await pdfrxFlutterInitialize();
    dir = Directory.systemTemp.createTempSync('daylight_pdf_touch');
    File('${dir.path}/p.png')
        .writeAsBytesSync(img.encodePng(img.Image(width: 600, height: 800)..clear(img.ColorRgb8(255, 255, 255))));
    path = '${dir.path}/doc.pdf';
    await ImageToPdf.convert(['${dir.path}/p.png'], path);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpViewer(WidgetTester tester) async {
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

  Future<void> settle(WidgetTester tester, [int ms = 1200]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// 화면의 쪽(순백 바탕)의 가로 길이와 지정한 색(노랑 손글씨) 픽셀 수.
  Future<({double pageWidth, int ink, int inkRows})> measure(WidgetTester tester) async {
    await settle(tester);
    final viewer = tester.getRect(find.byType(PdfViewer));
    RenderObject? node = tester.renderObject(find.byType(PdfViewer));
    while (node != null && node is! RenderRepaintBoundary) {
      node = node.parent;
    }
    final image = await (node! as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    var left = 1 << 30, right = -1, ink = 0;
    final rows = <int>{};
    for (var y = viewer.top.toInt(); y < viewer.bottom.toInt(); y++) {
      for (var x = viewer.left.toInt(); x < viewer.right.toInt(); x++) {
        final i = (y * image.width + x) * 4;
        final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
        if (r == 255 && g == 255 && b == 255) {
          if (x < left) left = x;
          if (x > right) right = x;
        } else if (r > 200 && g > 180 && b < 120) {
          ink++;
          rows.add(y);
        }
      }
    }
    return (pageWidth: (right - left + 1).toDouble(), ink: ink, inkRows: rows.length);
  }

  Future<void> chooseInk(WidgetTester tester) async {
    await tester.tap(find.byTooltip('손글씨'));
    await tester.pump();
  }

  Future<void> stroke(WidgetTester tester, Offset from, Offset to, PointerDeviceKind kind) async {
    final g = await tester.startGesture(from, kind: kind);
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 8)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
  }

  int annotationCount(WidgetTester tester) {
    final text = tester.widgetList<Text>(find.textContaining(RegExp(r'^주석 \d+$'))).map((t) => t.data).first!;
    return int.parse(text.split(' ').last);
  }

  double zoomOf(WidgetTester tester) => tester.widget<PdfViewer>(find.byType(PdfViewer)).controller!.currentZoom;

  Offset pageCenter(WidgetTester tester) => tester.getRect(find.byType(PdfViewer)).center;

  testWidgets('one finger draws, and the thick line is twice as thick as the medium one', (tester) async {
    await pumpViewer(tester);
    await chooseInk(tester);
    final c = pageCenter(tester);

    await stroke(tester, c + const Offset(-120, -100), c + const Offset(120, -100), PointerDeviceKind.touch);
    await settle(tester);
    expect(annotationCount(tester), 1);
    final thin = await measure(tester);
    expect(thin.ink, greaterThan(50), reason: 'the stroke is drawn');

    // 굵게(6pt): 보통(3pt)과 같은 길이의 선이 두 배 굵다. 보통 선의 픽셀이 thin.ink이므로 굵은 선은 그 두 배쯤이다
    await tester.tap(find.byTooltip('선 굵기: 굵게'));
    await tester.pump();
    await stroke(tester, c + const Offset(-120, 100), c + const Offset(120, 100), PointerDeviceKind.touch);
    await settle(tester);
    expect(annotationCount(tester), 2);
    final both = await measure(tester);
    final thickPixels = both.ink - thin.ink;
    expect(
      thickPixels,
      closeTo(thin.ink * 2, thin.ink * 0.35),
      reason: 'thick vs medium pixels: $thickPixels vs ${thin.ink}',
    );
  });

  testWidgets('a second finger cancels the stroke and zooms the page instead', (tester) async {
    await pumpViewer(tester);
    await chooseInk(tester);
    await settle(tester);
    final before = zoomOf(tester);
    final c = pageCenter(tester);

    final a = await tester.startGesture(c + const Offset(-60, 0), kind: PointerDeviceKind.touch, pointer: 1);
    await a.moveTo(c + const Offset(-70, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final b = await tester.startGesture(c + const Offset(60, 0), kind: PointerDeviceKind.touch, pointer: 2);
    for (var i = 1; i <= 10; i++) {
      await a.moveTo(c + Offset(-70.0 - i * 12, 0));
      await b.moveTo(c + Offset(60.0 + i * 12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(annotationCount(tester), 0, reason: 'the first finger stroke was discarded');
    final after = zoomOf(tester);
    expect(after, greaterThan(before * 1.5), reason: 'pinch zoomed in: $before -> $after');
  });

  testWidgets('the pen draws, fingers no longer draw afterwards, and a palm touch is ignored', (tester) async {
    await pumpViewer(tester);
    await chooseInk(tester);
    final c = pageCenter(tester);

    // 펜 한 획 (손바닥이 같이 닿아도 획은 끊기지 않는다)
    final pen = await tester.startGesture(c + const Offset(-100, -60), kind: PointerDeviceKind.stylus, pointer: 10);
    final palm = await tester.startGesture(c + const Offset(150, 150), kind: PointerDeviceKind.touch, pointer: 11);
    for (var i = 1; i <= 8; i++) {
      await pen.moveTo(c + Offset(-100.0 + i * 25, -60));
      await palm.moveTo(c + Offset(150.0 + i, 150));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pen.up();
    await palm.up();
    await settle(tester);
    expect(annotationCount(tester), 1, reason: 'one pen stroke, the palm drew nothing');

    // 그 뒤로 손가락은 그리지 않는다
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500))); // 펜 직후의 손바닥 보호 시간이 지난다
    await stroke(tester, c + const Offset(-100, 60), c + const Offset(100, 60), PointerDeviceKind.touch);
    await settle(tester);
    expect(annotationCount(tester), 1, reason: 'a finger no longer draws once a pen was used');
  });
}
