import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/theme/app_theme.dart';
import 'package:daylight_pdf/viewer/annotation_state.dart';
import 'package:daylight_pdf/viewer/annotation_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `flutter test`의 기본 플랫폼은 Android라서, 어느 쪽을 시험하는지 정해 준다.
void testTouch(String description, WidgetTesterCallback callback) =>
    testWidgets(description, callback, variant: TargetPlatformVariant.only(TargetPlatform.android));

void main() {
  Future<AnnotationState> pump(WidgetTester tester, {required double width, DrawTool tool = DrawTool.none}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = AnnotationState();
    addTearDown(state.dispose);
    if (tool != DrawTool.none) state.toggleTool(tool);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AnnotationToolbar(
            state: state,
            onHighlight: () {},
            onUnderline: () {},
            showList: false,
            onToggleList: () {},
            onUndo: () {},
            undoShortcut: '',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  for (final width in [1280.0, 800.0, 412.0]) {
    for (final tool in [DrawTool.none, DrawTool.ink, DrawTool.rectangle, DrawTool.note]) {
      testTouch('the touch toolbar does not overflow at ${width.toInt()} wide with tool $tool', (tester) async {
        await pump(tester, width: width, tool: tool);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testTouch('width choices and the finger/pen switch show only for line tools, with touch sized targets', (
    tester,
  ) async {
    final state = await pump(tester, width: 1280, tool: DrawTool.ink);
    expect(find.byTooltip('선 굵기: 가늘게'), findsOneWidget);
    expect(find.byTooltip('선 굵기: 굵게'), findsOneWidget);
    expect(find.text('손가락으로 그리기'), findsOneWidget);
    expect(tester.getSize(find.byTooltip('선 굵기: 굵게')).width, greaterThanOrEqualTo(44));

    await tester.tap(find.byTooltip('선 굵기: 굵게'));
    await tester.pump();
    expect(state.strokeWidth, AnnotationState.strokeWidths.last);

    await tester.tap(find.text('손가락으로 그리기'));
    await tester.pump();
    expect(state.fingerDraws, isFalse);
    expect(find.text('펜으로만 그리기'), findsOneWidget);
    expect(find.textContaining('펜으로 그리고'), findsOneWidget, reason: 'the hint explains the pen mode');

    state.toggleTool(DrawTool.note);
    await tester.pump();
    expect(find.byTooltip('선 굵기: 굵게'), findsNothing, reason: 'a note has no line width');
    expect(find.text('펜으로만 그리기'), findsNothing);
  });

  testWidgets(
    'on a desktop the toolbar keeps its mouse layout (no width choices for the note tool, no finger switch)',
    (tester) async {
      final state = await pump(tester, width: 1280, tool: DrawTool.ink);
      expect(find.text('손가락으로 그리기'), findsNothing, reason: 'the finger switch is for touch devices');
      expect(find.byTooltip('선 굵기: 굵게'), findsOneWidget, reason: 'line width is useful with a mouse too');
      state.toggleTool(DrawTool.note);
      await tester.pump();
      expect(find.byTooltip('선 굵기: 굵게'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
