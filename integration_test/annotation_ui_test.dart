// 실제 PDFium으로 보기 화면의 주석 도구를 구동한다:
//   flutter test integration_test/annotation_ui_test.dart -d macos
import 'dart:io';
import 'dart:ui' as ui;

import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/convert/svg_to_pdf.dart';
import 'package:daylight_pdf/pages/page_ops.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/viewer/annotation_panel.dart';
import 'package:daylight_pdf/viewer/viewer_screen.dart';
import 'package:daylight_pdf/widgets/glass_card.dart';
import 'package:daylight_pdf/widgets/tool_chip.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  Future<void> pumpViewer(WidgetTester tester, String path) async {
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

  /// 주석 목록 안에서만 찾는다 (도구 줄에도 같은 이름의 글자가 있다).
  Finder inPanel(String text) => find.descendant(of: find.byType(AnnotationPanel), matching: find.text(text));

  /// 화면에서 쪽(순백 바탕)이 차지한 영역을 잰다. 쪽 위치를 계산식으로 추정하면 창 크기나 배치가 바뀔 때 어긋나므로
  /// (글자 줄을 놓치기도 한다) 실제로 그려진 모습에서 찾는다.
  Future<Rect> measurePage(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1))); // 쪽 이미지가 그려질 시간
    await tester.pump();
    final viewer = tester.getRect(find.byType(PdfViewer));
    RenderObject? node = tester.renderObject(find.byType(PdfViewer));
    while (node != null && node is! RenderRepaintBoundary) {
      node = node.parent;
    }
    final image = await (node! as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    var left = 1 << 30, top = 1 << 30, right = -1, bottom = -1;
    for (var y = viewer.top.toInt(); y < viewer.bottom.toInt(); y++) {
      for (var x = viewer.left.toInt(); x < viewer.right.toInt(); x++) {
        final i = (y * image.width + x) * 4;
        if (rgba[i] == 255 && rgba[i + 1] == 255 && rgba[i + 2] == 255) {
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
    }
    expect(right - left, greaterThan(50), reason: 'the page must be visible');
    return Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0);
  }

  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
    final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 8)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  }

  /// 뒤로 가기. 앱 바의 뒤로 가기 버튼(플랫폼마다 다른 위젯)이나 PopScope를 거치는 `maybePop`과 같은 경로다.
  Future<void> back(WidgetTester tester) async {
    await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await tester.pumpAndSettle();
  }

  /// 뷰어를 감싼 가장 가까운 RepaintBoundary를 PNG로 떠서 [name]으로 남긴다 (눈으로 확인하는 용도).
  Future<void> snapshot(WidgetTester tester, String name) async {
    // PDFium 렌더링은 비동기라 프레임이 안 돌아도 끝난다: 잠깐 기다렸다가 그린다.
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    RenderObject? node = tester.renderObject(find.byType(PdfViewer));
    while (node != null && node is! RenderRepaintBoundary) {
      node = node.parent;
    }
    final image = await (node! as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    File('${Directory.systemTemp.path}/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
  }

  testWidgets('draw, note, highlight and delete annotations in the viewer', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_annot_ui');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/doc.svg').writeAsStringSync(
      '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="200">'
      '<rect width="400" height="200" fill="#ffffff"/>'
      '<text x="20" y="60" font-family="Helvetica" font-size="32" fill="#000000">Highlight this line</text>'
      '<text x="20" y="110" font-family="Helvetica" font-size="32" fill="#000000">Second line here</text></svg>',
    );
    await SvgToPdf.convert('${dir.path}/doc.svg', '${dir.path}/doc.pdf');
    await pumpViewer(tester, '${dir.path}/doc.pdf');

    var page = await measurePage(tester);
    Offset onPage(double fx, double fy) => Offset(page.left + page.width * fx, page.top + page.height * fy);

    // 아무것도 선택하지 않고 형광펜 → 안내만 나온다
    await tester.tap(find.byTooltip('형광펜 (선택한 글자)'));
    await tester.pumpAndSettle();
    expect(find.text('먼저 글자를 선택하세요'), findsOneWidget);

    // 손글씨
    await tester.tap(find.byTooltip('손글씨'));
    await tester.pumpAndSettle();
    await drag(tester, onPage(0.3, 0.75), onPage(0.6, 0.9));
    // 사각형
    await tester.tap(find.byTooltip('사각형'));
    await tester.pumpAndSettle();
    await drag(tester, onPage(0.65, 0.15), onPage(0.85, 0.4));
    // 원
    await tester.tap(find.byTooltip('원'));
    await tester.pumpAndSettle();
    await drag(tester, onPage(0.65, 0.55), onPage(0.85, 0.85));

    // 메모: 클릭 → 입력 → 추가
    await tester.tap(find.byTooltip('메모 (쪽을 클릭)'));
    await tester.pumpAndSettle();
    final tap = await tester.startGesture(onPage(0.1, 0.85), kind: PointerDeviceKind.mouse);
    await tap.up();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '확인할 메모 note');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('메모 (쪽을 클릭)')); // 도구 끄기
    await tester.pumpAndSettle();

    // 목록에 4개 (손글씨, 사각형, 원, 메모)
    await tester.tap(find.byTooltip('주석 목록'));
    await tester.pumpAndSettle();
    expect(inPanel('확인할 메모 note'), findsOneWidget);
    expect(inPanel('손글씨'), findsOneWidget);
    expect(inPanel('사각형'), findsOneWidget);
    expect(inPanel('원'), findsOneWidget);

    // 글자 선택(마우스 끌기) → 형광펜. 목록이 열려 뷰어 너비가 줄었으니 다시 잰다.
    await tester.pumpAndSettle();
    // 글자 선택은 쪽의 글자 정보가 비동기로 로드된 뒤에야 된다: measurePage가 잠깐 기다리며 쪽을 다시 잰다.
    page = await measurePage(tester);
    await drag(tester, onPage(0.06, 0.25), onPage(0.60, 0.25));
    await tester.tap(find.byTooltip('형광펜 (선택한 글자)'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await snapshot(tester, 'daylight_pdf_viewer_annotated'); // 실패해도 화면을 볼 수 있게 확인 전에 남긴다
    final highlighted = inPanel('형광펜').evaluate().isNotEmpty;
    expect(highlighted, isTrue, reason: 'selecting text and pressing highlight must add a highlight');

    // 삭제: 사각형을 지운다
    final before = find.byIcon(Icons.delete_outline_rounded).evaluate().length;
    final rectTile = find.ancestor(of: inPanel('사각형'), matching: find.byType(GlassCard));
    await tester.tap(find.descendant(of: rectTile, matching: find.byIcon(Icons.delete_outline_rounded)));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(inPanel('사각형'), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded).evaluate().length, before - 1);
    await snapshot(tester, 'daylight_pdf_viewer_after_delete');

    // ignore: avoid_print
    print('HIGHLIGHT_APPLIED=$highlighted DIR=${Directory.systemTemp.path}');
  });

  testWidgets('leaving with unsaved annotations asks first; cancel stays, discard leaves', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_annot_ui');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/p.png')
        .writeAsBytesSync(img.encodePng(img.Image(width: 400, height: 200)..clear(img.ColorRgb8(255, 255, 255))));
    await ImageToPdf.convert(['${dir.path}/p.png'], '${dir.path}/doc.pdf');

    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => ViewerScreen(path: '${dir.path}/doc.pdf'))),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 주석이 없으면 바로 나간다
    await back(tester);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final viewer = tester.getRect(find.byType(PdfViewer));
    await tester.tap(find.byTooltip('사각형'));
    await tester.pumpAndSettle();
    await drag(tester, viewer.center - const Offset(40, 20), viewer.center + const Offset(40, 20));

    await back(tester);
    await tester.pumpAndSettle();
    expect(find.text('저장하지 않은 주석이 있어요'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsOneWidget, reason: 'cancel keeps the viewer');

    await back(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장 안 함'));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a drawn rectangle lands where it was drawn, also on a page rotated by 90 degrees', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_annot_ui');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/p.png')
        .writeAsBytesSync(img.encodePng(img.Image(width: 400, height: 200)..clear(img.ColorRgb8(255, 255, 255))));
    await ImageToPdf.convert(['${dir.path}/p.png'], '${dir.path}/flat.pdf');
    await PageOps.build([PageRef('${dir.path}/flat.pdf', 0, quarterTurns: 1)], '${dir.path}/rotated.pdf');

    Future<({int w, int h, List<int> rgba})> capture() async {
      RenderObject? node = tester.renderObject(find.byType(PdfViewer));
      while (node != null && node is! RenderRepaintBoundary) {
        node = node.parent;
      }
      final image = await (node! as RenderRepaintBoundary).toImage(pixelRatio: 1);
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return (w: image.width, h: image.height, rgba: data.buffer.asUint8List());
    }

    // 회전한 쪽은 문서에서도 세로(200x400)로 보여야 한다 (테스트 자료 점검).
    final rotatedDoc = await PdfDocument.openFile('${dir.path}/rotated.pdf');
    expect([rotatedDoc.pages.first.width, rotatedDoc.pages.first.height], [200, 400]);
    rotatedDoc.dispose();

    for (final name in ['flat', 'rotated']) {
      await pumpViewer(tester, '${dir.path}/$name.pdf');
      await tester.tap(find.byTooltip('주석 목록')); // 목록은 닫아 둔다 (기본은 닫힘 → 눌러서 열렸다면 다시 닫기)
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('주석 목록'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await tester.pump();

      // 쪽(순백)이 차지한 화면 영역을 찾는다: 뷰어 안에서 R=G=B=255인 픽셀의 경계.
      final viewer = tester.getRect(find.byType(PdfViewer));
      final before = await capture();
      var left = 1 << 30, top = 1 << 30, right = -1, bottom = -1;
      for (var y = viewer.top.toInt(); y < viewer.bottom.toInt(); y++) {
        for (var x = viewer.left.toInt(); x < viewer.right.toInt(); x++) {
          final i = (y * before.w + x) * 4;
          if (before.rgba[i] == 255 && before.rgba[i + 1] == 255 && before.rgba[i + 2] == 255) {
            if (x < left) left = x;
            if (x > right) right = x;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
      }
      expect(right - left, greaterThan(50), reason: '$name: page must be visible');
      final page = Rect.fromLTRB(left.toDouble(), top.toDouble(), right.toDouble() + 1, bottom.toDouble() + 1);
      await tester.tap(find.byTooltip('사각형'));
      await tester.pumpAndSettle();
      final from = Offset(page.left + page.width * 0.25, page.top + page.height * 0.25);
      final to = Offset(page.left + page.width * 0.75, page.top + page.height * 0.5);
      await drag(tester, from, to);
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await snapshot(tester, 'daylight_pdf_rect_$name');
      // 노란 테두리(R,G 높고 B 낮음)가 그린 사각형의 네 변 위에 있어야 한다.
      final after = await capture();
      bool yellow(int x, int y) {
        for (var dy = -3; dy <= 3; dy++) {
          for (var dx = -3; dx <= 3; dx++) {
            final i = ((y + dy) * after.w + (x + dx)) * 4;
            if (after.rgba[i] > 200 && after.rgba[i + 1] > 180 && after.rgba[i + 2] < 120) return true;
          }
        }
        return false;
      }

      final midX = ((from.dx + to.dx) / 2).round(), midY = ((from.dy + to.dy) / 2).round();
      expect(yellow(midX, from.dy.round()), isTrue, reason: '$name: top edge');
      expect(yellow(midX, to.dy.round()), isTrue, reason: '$name: bottom edge');
      expect(yellow(from.dx.round(), midY), isTrue, reason: '$name: left edge');
      expect(yellow(to.dx.round(), midY), isTrue, reason: '$name: right edge');
      expect(yellow(midX, midY), isFalse, reason: '$name: inside stays empty (outline only)');
    }
  });

  testWidgets('Cmd+Z and the Undo button remove the last annotation, one step at a time', (tester) async {
    await pdfrxFlutterInitialize();
    final dir = Directory.systemTemp.createTempSync('daylight_pdf_undo');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/p.png')
        .writeAsBytesSync(img.encodePng(img.Image(width: 400, height: 200)..clear(img.ColorRgb8(255, 255, 255))));
    await ImageToPdf.convert(['${dir.path}/p.png'], '${dir.path}/doc.pdf');
    await pumpViewer(tester, '${dir.path}/doc.pdf');

    final undoChip = find.byWidgetPredicate((w) => w is ToolChip && w.icon == Icons.undo_rounded);
    bool undoEnabled() => tester.widget<ToolChip>(undoChip).onPressed != null;
    expect(undoEnabled(), isFalse, reason: 'nothing to undo yet');

    await tester.tap(find.byTooltip('주석 목록'));
    await tester.pumpAndSettle();
    final page = await measurePage(tester);
    Offset onPage(double fx, double fy) => Offset(page.left + page.width * fx, page.top + page.height * fy);

    await tester.tap(find.byTooltip('사각형'));
    await tester.pumpAndSettle();
    await drag(tester, onPage(0.2, 0.2), onPage(0.5, 0.6));
    await tester.tap(find.byTooltip('손글씨'));
    await tester.pumpAndSettle();
    await drag(tester, onPage(0.6, 0.3), onPage(0.9, 0.8));
    await tester.tap(find.byTooltip('손글씨')); // 도구 끄기
    await tester.pumpAndSettle();
    expect(inPanel('사각형'), findsOneWidget);
    expect(inPanel('손글씨'), findsOneWidget);
    expect(undoEnabled(), isTrue);

    Future<void> pressCmdZ() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    }

    await pressCmdZ(); // 마지막(손글씨)만 사라진다
    expect(inPanel('손글씨'), findsNothing);
    expect(inPanel('사각형'), findsOneWidget);
    expect(undoEnabled(), isTrue);

    await tester.tap(undoChip); // 버튼도 같은 동작
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(inPanel('사각형'), findsNothing);
    expect(find.text('주석이 없어요'), findsOneWidget);
    expect(undoEnabled(), isFalse);

    await pressCmdZ(); // 더 되돌릴 게 없어도 아무 일 없다
    expect(find.text('주석이 없어요'), findsOneWidget);
  });
}
