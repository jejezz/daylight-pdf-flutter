import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/viewer/note_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NoteDialogResult? result;
  var done = false;

  Future<void> open(WidgetTester tester, {String text = '기존 메모'}) async {
    result = null;
    done = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showNoteDialog(context, initialText: text, pageNumber: 3);
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, '저장'));

  testWidgets('shows the existing note text and its page, and Save is off until the text changes', (tester) async {
    await open(tester);
    expect(find.widgetWithText(TextField, '기존 메모'), findsOneWidget);
    expect(find.text('3쪽'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '기존 메모');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull, reason: 'same text is not a change');
  });

  testWidgets('editing then saving returns the trimmed new text', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '  고친 메모 ✓  ');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(result?.action, NoteDialogAction.save);
    expect(result?.text, '고친 메모 ✓');
  });

  testWidgets('an empty note cannot be saved', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('Delete returns the delete action', (tester) async {
    await open(tester);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(result?.action, NoteDialogAction.delete);
  });

  testWidgets('Close leaves the note untouched (null result), even after typing', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '버려질 글');
    await tester.pump();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(result, isNull);
  });
}
