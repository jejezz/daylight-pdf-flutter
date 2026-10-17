import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/pages/merge_tab.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('each file row counts its pages once, however many times the list is rebuilt', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    final calls = <String>[];
    Future<int> fakeCount(String path) async {
      calls.add(path);
      return path.endsWith('a.pdf') ? 3 : 5;
    }

    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MergeTab(initialFiles: const ['/x/a.pdf', '/x/b.pdf'], countPages: fakeCount),
          ),
        ),
      ),
    );
    // 쪽 수 결과가 도착해 다시 그려지는 일을 여러 번 겪게 한다. 예전에는 그때마다 파일을 다시 열었다.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(calls, ['/x/a.pdf', '/x/b.pdf']);
    expect(find.text('3쪽'), findsOneWidget);
    expect(find.text('5쪽'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing keeps asking for frames once counts are shown');
  });

  testWidgets('a file whose pages cannot be counted shows a failure pill instead of crashing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MergeTab(initialFiles: const ['/x/bad.pdf'], countPages: (_) async => throw StateError('nope')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('파일을 읽을 수 없어요'), findsOneWidget);
  });
}
