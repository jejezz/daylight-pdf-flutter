// 모든 화면을 라이트·다크로 1200x720에서 PNG로 떠서 시스템 임시 폴더의 `daylight_pdf_ui/`에 남긴다.
// 디자인을 눈으로 확인하거나 README 스크린샷을 만들 때 쓴다 (검사는 하지 않는다):
//   flutter test integration_test/ui_gallery_test.dart -d macos
import 'dart:io';
import 'dart:ui' as ui;

import 'package:daylight_pdf/convert/convert_screen.dart';
import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/home/home_screen.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/pages/edit_tab.dart';
import 'package:daylight_pdf/pages/merge_tab.dart';
import 'package:daylight_pdf/pages/page_tools_screen.dart';
import 'package:daylight_pdf/pages/split_tab.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/theme/app_theme.dart';
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

  testWidgets('ui gallery', (tester) async {
    await pdfrxFlutterInitialize();
    tester.view.physicalSize = const Size(1200, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final out = Directory('${Directory.systemTemp.path}/daylight_pdf_ui')..createSync(recursive: true);
    final work = Directory.systemTemp.createTempSync('daylight_pdf_gallery');
    addTearDown(() => work.deleteSync(recursive: true));

    // 자료: 색 있는 이미지 3장 → 3쪽 PDF, 개별 이미지, SVG, 비호환 .ai
    final colors = [img.ColorRgb8(255, 196, 120), img.ColorRgb8(150, 200, 255), img.ColorRgb8(180, 230, 180)];
    final pngs = <String>[];
    for (var i = 0; i < 3; i++) {
      final im = img.Image(width: 400, height: 260)..clear(colors[i]);
      pngs.add('${work.path}/page$i.png');
      File(pngs[i]).writeAsBytesSync(img.encodePng(im));
    }
    await ImageToPdf.convert(pngs, '${work.path}/report.pdf');
    File('${work.path}/logo.svg').writeAsStringSync(
      '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><circle cx="50" cy="50" r="40" fill="#4C9DFF"/></svg>',
    );
    File('${work.path}/old.ai').writeAsStringSync('%!PS-Adobe-3.0 EPSF-3.0\n');

    // 최근 파일 10개 (실제 파일이어야 목록에 나온다)
    final recentFiles = <String>[];
    for (var i = 0; i < 10; i++) {
      final f = File('${work.path}/문서 ${i + 1}.pdf')
        ..writeAsBytesSync(File('${work.path}/report.pdf').readAsBytesSync());
      recentFiles.add(f.path);
    }

    Future<void> shoot(String name) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      RenderObject? node = tester.renderObject(find.byType(Scaffold).first);
      while (node != null && node is! RenderRepaintBoundary) {
        node = node.parent;
      }
      final image = await (node! as RenderRepaintBoundary).toImage(pixelRatio: 1);
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      File('${out.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
    }

    Future<void> pump(Widget home, ThemeMode mode, {Map<String, Object> prefs = const {}}) async {
      SharedPreferences.setMockInitialValues(prefs);
      final settings = await AppSettings.load();
      await tester.pumpWidget(
        AppSettingsScope(
          settings: settings,
          child: MaterialApp(
            key: UniqueKey(),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(dense: true),
            darkTheme: AppTheme.dark(dense: true),
            themeMode: mode,
            locale: const Locale('ko'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        ),
      );
      // pumpAndSettle 대신 한정된 횟수만 돌린다 (끝나지 않는 프레임이 있으면 시간이 드러나게).
      final sw = Stopwatch()..start();
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      // ignore: avoid_print
      print(
        'PUMPED ${home.runtimeType} ${sw.elapsedMilliseconds}ms hasScheduledFrame=${tester.binding.hasScheduledFrame}',
      );
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final m = mode.name;
      await pump(HomeScreen(onAbout: () {}), mode);
      await shoot('home_$m');
      await pump(HomeScreen(onAbout: () {}), mode, prefs: {'recent_files': recentFiles});
      await shoot('home_recent_$m');
      await pump(
        ConvertScreen(
          initialPaths: [
            pngs[0],
            pngs[1],
            '${work.path}/report.pdf',
            '${work.path}/logo.svg',
            '${work.path}/old.ai',
            '${work.path}/x.heic',
          ],
        ),
        mode,
      );
      await shoot('convert_$m');
      await pump(PageToolsScreen(initialPath: '${work.path}/report.pdf'), mode);
      await shoot('edit_$m');
      await pump(ViewerScreen(path: '${work.path}/report.pdf'), mode);
      await shoot('viewer_$m');
    }
    // 내용이 있는 상태들 (라이트)
    await pump(PageToolsScreen(initialPath: '${work.path}/report.pdf'), ThemeMode.light);
    await tester.tap(find.byType(PageTile).first);
    await tester.pump();
    await tester.tap(find.byType(PageTile).at(1));
    await tester.pump();
    await tester.tap(find.byTooltip('오른쪽으로 회전'));
    await shoot('edit_selected_light');
    await pump(
      Scaffold(body: MergeTab(initialFiles: ['${work.path}/report.pdf', '${work.path}/report.pdf'])),
      ThemeMode.light,
    );
    await shoot('merge_files_light');
    await pump(Scaffold(body: SplitTab(initialPath: '${work.path}/report.pdf')), ThemeMode.light);
    await shoot('split_loaded_light');
    await pump(const PageToolsScreen(), ThemeMode.light);
    await tester.tap(find.text('합치기'));
    await tester.pump();
    await shoot('merge_light');
  });
}
