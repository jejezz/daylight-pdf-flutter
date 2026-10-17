import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/pages/page_tools_screen.dart';
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
  testWidgets('three tabs, each with a clear empty state (ko)', (tester) async {
    await tester.pumpWidget(await _app(const PageToolsScreen(), const Locale('ko')));
    await tester.pump();
    expect(find.text('편집'), findsOneWidget);
    expect(find.text('합치기'), findsOneWidget);
    expect(find.text('나누기'), findsOneWidget);
    expect(find.text('편집할 PDF를 열거나 끌어다 놓으세요'), findsOneWidget);

    await tester.tap(find.text('합치기'));
    await tester.pumpAndSettle();
    expect(find.text('합칠 PDF를 추가하세요'), findsOneWidget);
    expect(find.text('PDF 추가'), findsOneWidget);
    expect(find.text('합쳐서 저장'), findsNothing, reason: 'the merge button appears once there are files to merge');

    await tester.tap(find.text('나누기'));
    await tester.pumpAndSettle();
    expect(find.text('나눌 PDF 선택'), findsOneWidget);
  });
}
