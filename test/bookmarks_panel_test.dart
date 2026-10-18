import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/viewer/bookmarks_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ko'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 248, child: child)),
);

void main() {
  testWidgets('empty list shows the hint', (tester) async {
    await tester.pumpWidget(_host(BookmarksPanel(pages: const [], current: 1, onTap: (_) {}, onDelete: (_) {})));
    expect(find.textContaining('아직 북마크가 없어요'), findsOneWidget);
  });

  testWidgets('tapping a row goes to that page and the close button deletes it', (tester) async {
    final went = <int>[], deleted = <int>[];
    await tester.pumpWidget(
      _host(BookmarksPanel(pages: const [2, 7], current: 2, onTap: went.add, onDelete: deleted.add)),
    );
    await tester.tap(find.text('7쪽'));
    expect(went, [7]);
    await tester.tap(find.byTooltip('북마크 지우기').first);
    expect(deleted, [2]);
  });
}
