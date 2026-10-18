import 'dart:io';

import 'package:daylight_pdf/home/home_screen.dart';
import 'package:daylight_pdf/home/recent_files.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/theme/app_theme.dart';
import 'package:daylight_pdf/widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `flutter test`의 기본 플랫폼은 Android라서, 화면이 플랫폼에 따라 다르면 어느 쪽을 시험하는지 정해 준다.
void testMobile(String description, WidgetTesterCallback callback) =>
    testWidgets(description, callback, variant: TargetPlatformVariant.only(TargetPlatform.android));

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('daylight_pdf_home_mobile');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpHome(
    WidgetTester tester, {
    required int count,
    Size size = const Size(1280, 800),
    String lang = 'ko',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final files = [
      for (var i = 0; i < count; i++) (File('${dir.path}/문서 $i.pdf')..writeAsBytesSync(List.filled(2048, 1))).path,
    ];
    SharedPreferences.setMockInitialValues({'recent_files': files.reversed.toList()});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(onAbout: () {}, recents: RecentFiles()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testMobile('empty state: one big open card and a friendly hint, no desktop-only actions', (tester) async {
    await pumpHome(tester, count: 0);
    expect(find.text('PDF 열기'), findsOneWidget);
    expect(find.text('PDF를 열어 읽고 메모해 보세요'), findsOneWidget);
    expect(find.textContaining('끌어다'), findsNothing, reason: 'no drag-and-drop wording on a touch device');
    expect(find.text('변환'), findsNothing);
    expect(find.text('페이지 도구'), findsNothing);
    expect(find.text('최근 파일'), findsNothing);
  });

  testMobile('recent files are touch sized cards with date and size, newest first', (tester) async {
    await pumpHome(tester, count: 3);
    expect(find.text('최근 파일'), findsOneWidget);
    final names = tester.widgetList<Text>(find.textContaining(RegExp(r'^문서 \d\.pdf$'))).map((t) => t.data).toList();
    expect(names, ['문서 2.pdf', '문서 1.pdf', '문서 0.pdf']);
    expect(find.textContaining('2.0 KB'), findsNWidgets(3), reason: 'size is shown next to the date');
    // 카드는 손가락으로 누르기 충분히 크다 (높이 72 이상): 첫 카드는 "PDF 열기", 그다음이 최근 파일들
    final cards = find.byType(GlassCard);
    expect(cards, findsNWidgets(4));
    for (var i = 1; i < 4; i++) {
      expect(tester.getSize(cards.at(i)).height, greaterThanOrEqualTo(72));
    }
  });

  testMobile('a phone width uses one column and still fits ten recent files by scrolling', (tester) async {
    await pumpHome(tester, count: 10, size: const Size(412, 900));
    expect(find.text('PDF 열기'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'no layout overflow on a phone');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('문서 0.pdf'), findsOneWidget, reason: 'the oldest file is reachable by scrolling');
  });

  testMobile('English strings', (tester) async {
    await pumpHome(tester, count: 0, lang: 'en');
    expect(find.text('Open a PDF'), findsOneWidget);
    expect(find.text('Open a PDF to read and take notes'), findsOneWidget);
  });

  test('formatFileSize', () {
    expect(formatFileSize(512), '512 B');
    expect(formatFileSize(2048), '2.0 KB');
    expect(formatFileSize(150 * 1024), '150 KB');
    expect(formatFileSize(5 * 1024 * 1024), '5.0 MB');
    expect(formatFileSize(3 * 1024 * 1024 * 1024), '3.0 GB');
  });
}
