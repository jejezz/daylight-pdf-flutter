import 'dart:io';

import 'package:daylight_pdf/home/home_screen.dart';
import 'package:daylight_pdf/home/recent_files.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:daylight_pdf/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('daylight_pdf_home_recent'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// 실제 파일 [count]개를 만들고, 최신순(마지막이 맨 앞)으로 최근 목록에 심은 뒤 홈 화면을 띄운다.
  Future<List<String>> pumpHome(WidgetTester tester, {required int count, Size size = const Size(1200, 720)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final files = [for (var i = 0; i < count; i++) (File('${dir.path}/doc$i.pdf')..writeAsStringSync('x')).path];
    SharedPreferences.setMockInitialValues({'recent_files': files.reversed.toList()});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(onAbout: () {}, recents: RecentFiles()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return files;
  }

  testWidgets('without recent files there is no recent section', (tester) async {
    await pumpHome(tester, count: 0);
    expect(find.text('최근 파일'), findsNothing);
    expect(find.text('파일 열기'), findsOneWidget);
  });

  testWidgets('shows recent files newest first, with name and folder', (tester) async {
    await pumpHome(tester, count: 3);
    expect(find.text('최근 파일'), findsOneWidget);
    final names = tester.widgetList<Text>(find.textContaining(RegExp(r'^doc\d\.pdf$'))).map((t) => t.data).toList();
    expect(names, ['doc2.pdf', 'doc1.pdf', 'doc0.pdf']);
    expect(
      find.text(shortFolder('${dir.path}/doc0.pdf')),
      findsNWidgets(3),
      reason: 'each row shows its (shortened) folder',
    );
  });

  testWidgets('all ten recent files are visible at once in the default window', (tester) async {
    await pumpHome(tester, count: 10);
    expect(find.textContaining(RegExp(r'^doc\d\.pdf$')), findsNWidgets(10));
  });

  testWidgets('in the smallest window the list scrolls but the main actions stay visible', (tester) async {
    await pumpHome(tester, count: 10, size: const Size(960, 600));
    expect(find.textContaining(RegExp(r'^doc\d\.pdf$')).evaluate().length, greaterThanOrEqualTo(6));
    expect(find.text('변환'), findsOneWidget);
    expect(find.text('페이지 도구'), findsOneWidget);
  });

  for (final size in [const Size(1200, 720), const Size(960, 600)]) {
    testWidgets('ten recent files fit without overflow at ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      await pumpHome(tester, count: 10, size: size);
      // 넘침(RenderFlex overflow)이 있으면 위젯 테스트가 예외로 실패한다. 주요 단추는 그대로 보여야 한다.
      expect(find.text('파일 열기'), findsOneWidget);
      expect(find.text('변환'), findsOneWidget);
      expect(find.text('페이지 도구'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('removing one entry and clearing the list update the screen and the store', (tester) async {
    await pumpHome(tester, count: 3);
    await tester.tap(find.byTooltip('목록에서 지우기').first); // 맨 앞 = doc2
    await tester.pumpAndSettle();
    expect(find.text('doc2.pdf'), findsNothing);
    expect(find.text('doc1.pdf'), findsOneWidget);
    expect((await RecentFiles().load()).length, 2);

    await tester.tap(find.text('목록 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('최근 파일'), findsNothing);
    expect(await RecentFiles().load(), isEmpty);
  });

  testWidgets('a recent file that disappeared is reported and dropped when tapped', (tester) async {
    final files = await pumpHome(tester, count: 2);
    File(files[1]).deleteSync(); // doc1이 맨 앞인데 그새 지워진 상황
    await tester.tap(find.text('doc1.pdf'));
    await tester.pumpAndSettle();
    expect(find.textContaining('파일을 읽을 수 없어요: doc1.pdf'), findsOneWidget);
    expect(find.text('doc1.pdf'), findsNothing);
    expect(find.text('doc0.pdf'), findsOneWidget);
    expect(await RecentFiles().load(), [files[0]]);
  });
}
