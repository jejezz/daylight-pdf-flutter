import 'package:daylight_pdf/engine/annotations/annotation_specs.dart';
import 'package:daylight_pdf/engine/annotations/pdfium_annotations.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/viewer/annotation_panel.dart';
import 'package:daylight_pdf/viewer/annotation_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

class _FakeDocument extends Fake implements PdfDocument {}

class _ReadOnlyBackend implements AnnotationBackend {
  _ReadOnlyBackend(this.items);
  final List<ReadAnnotation> items;

  @override
  Future<List<ReadAnnotation>> read(PdfDocument document, {Set<int>? pages}) async => items;

  @override
  Future<void> add(PdfDocument document, List<PdfAnnotationSpec> specs) async {}

  @override
  Future<void> remove(PdfDocument document, int pageIndex, int index) async {}

  @override
  Future<void> setContents(PdfDocument document, int pageIndex, int index, String text) async {}
}

ReadAnnotation _a(int page, int subtype, String text) =>
    ReadAnnotation(pageIndex: page, index: 0, subtype: subtype, contents: text);

void main() {
  final items = [_a(0, 1, 'Buy Milk'), _a(1, 1, '우유 사기'), _a(2, 15, '')];

  test('filterAnnotations matches contents, ignoring case and outer spaces', () {
    expect(filterAnnotations(items, ''), items);
    expect(filterAnnotations(items, '  ').length, 3);
    expect(filterAnnotations(items, 'milk').map((a) => a.pageIndex), [0]);
    expect(filterAnnotations(items, ' 우유 ').map((a) => a.pageIndex), [1]);
    expect(filterAnnotations(items, 'zzz'), isEmpty);
  });

  testWidgets('typing in the search box narrows the list and clearing restores it', (tester) async {
    final state = AnnotationState(_ReadOnlyBackend(items));
    await state.refresh(_FakeDocument());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: AnnotationPanel(state: state, onJump: (_) {}, onOpenNote: (_) {}, onDelete: (_) {}),
          ),
        ),
      ),
    );
    expect(find.text('Buy Milk'), findsOneWidget);
    expect(find.text('우유 사기'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'milk');
    await tester.pump();
    expect(find.text('Buy Milk'), findsOneWidget);
    expect(find.text('우유 사기'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pump();
    expect(find.text('일치하는 주석이 없어요'), findsOneWidget);

    await tester.tap(find.byTooltip('검색어 지우기'));
    await tester.pump();
    expect(find.text('Buy Milk'), findsOneWidget);
    expect(find.text('우유 사기'), findsOneWidget);
  });

  testWidgets('no search box when there are no annotations', (tester) async {
    final state = AnnotationState(_ReadOnlyBackend(const []));
    await state.refresh(_FakeDocument());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AnnotationPanel(state: state, onJump: (_) {}, onOpenNote: (_) {}, onDelete: (_) {}),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('주석이 없어요'), findsOneWidget);
  });
}
