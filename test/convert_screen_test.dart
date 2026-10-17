import 'package:daylight_pdf/convert/convert_screen.dart';
import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app(Widget home, Locale locale) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await AppSettings.load();
  return AppSettingsScope(
    settings: settings,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  testWidgets('empty convert screen explains what to drop and offers the options (ko)', (tester) async {
    await tester.pumpWidget(await _app(const ConvertScreen(), const Locale('ko')));
    await tester.pump();
    expect(find.text('변환할 이미지나 PDF를 끌어다 놓으세요'), findsOneWidget);
    expect(find.text('이미지를 한 PDF로 합치기'), findsOneWidget);
    expect(find.text('원본과 같은 폴더'), findsOneWidget);
    expect(find.text('150 DPI'), findsOneWidget);
  });

  testWidgets('unsupported files are skipped with a message and queue nothing (en)', (tester) async {
    await tester.pumpWidget(
      await _app(const ConvertScreen(initialPaths: ['/x/photo.heic', '/x/drawing.ai']), const Locale('en')),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Skipped 2 unsupported files'), findsOneWidget);
    expect(find.text('Drop images or PDFs to convert'), findsOneWidget);
  });
}
