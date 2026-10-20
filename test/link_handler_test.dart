import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/viewer/link_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  test('only web and mail addresses may be opened outside the app', () {
    expect(isOpenableLinkUrl(Uri.parse('https://example.com')), isTrue);
    expect(isOpenableLinkUrl(Uri.parse('HTTP://example.com')), isTrue);
    expect(isOpenableLinkUrl(Uri.parse('mailto:a@b.c')), isTrue);
    expect(isOpenableLinkUrl(Uri.parse('file:///etc/passwd')), isFalse);
    expect(isOpenableLinkUrl(Uri.parse('javascript:alert(1)')), isFalse);
  });

  Future<BuildContext> pump(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  const rects = <PdfRect>[];

  testWidgets('an internal link goes to its destination without asking', (tester) async {
    final ctx = await pump(tester);
    PdfDest? went;
    final dest = PdfDest(3, PdfDestCommand.fit, null);
    await handlePdfLink(
      ctx,
      PdfLink(rects, dest: dest),
      goToDest: (d) async => went = d,
      confirm: (_, _) async => fail('internal links must not ask'),
      launch: (_) async => fail('internal links must not launch'),
    );
    expect(went, dest);
  });

  testWidgets('a web link is opened only after confirmation', (tester) async {
    final ctx = await pump(tester);
    final launched = <Uri>[];
    final url = Uri.parse('https://example.com/a');
    Future<void> tap(bool answer) => handlePdfLink(
      ctx,
      PdfLink(rects, url: url),
      goToDest: (_) async => fail('no dest'),
      confirm: (_, _) async => answer,
      launch: (u) async {
        launched.add(u);
        return true;
      },
    );
    await tap(false);
    expect(launched, isEmpty);
    await tap(true);
    expect(launched, [url]);
  });

  testWidgets('a link that cannot be launched, or is not allowed, shows a message', (tester) async {
    final ctx = await pump(tester);
    await handlePdfLink(
      ctx,
      PdfLink(rects, url: Uri.parse('https://example.com')),
      goToDest: (_) async {},
      confirm: (_, _) async => true,
      launch: (_) async => false,
    );
    await tester.pump();
    expect(find.text('링크를 열 수 없어요.'), findsOneWidget);
    ScaffoldMessenger.of(ctx).clearSnackBars();
    await tester.pumpAndSettle();

    await handlePdfLink(
      ctx,
      PdfLink(rects, url: Uri.parse('file:///tmp/x')),
      goToDest: (_) async {},
      confirm: (_, _) async => fail('must not ask for a disallowed scheme'),
      launch: (_) async => fail('must not launch a disallowed scheme'),
    );
    await tester.pump();
    expect(find.text('이 링크는 열지 않아요.'), findsOneWidget);
  });

  testWidgets('the confirm dialog shows the address and returns the answer', (tester) async {
    final ctx = await pump(tester);
    final future = confirmOpenLink(ctx, Uri.parse('https://example.com/a'));
    await tester.pumpAndSettle();
    expect(find.textContaining('https://example.com/a'), findsOneWidget);
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(await future, isTrue);

    final again = confirmOpenLink(ctx, Uri.parse('https://example.com/a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(await again, isFalse);
  });
}
