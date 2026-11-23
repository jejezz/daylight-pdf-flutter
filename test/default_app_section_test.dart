import 'dart:io';

import 'package:daylight_pdf/l10n/app_localizations.dart';
import 'package:daylight_pdf/platform/default_app_section.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('ko'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('Windows: 설정 열기 단추, 단계 4개, 형식 칩, 누르면 복사', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    var opened = 0;
    await tester.pumpWidget(
      _host(
        DefaultAppSection(
          openSettings: () async {
            opened++;
            return true;
          },
        ),
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(DefaultAppSection)));

    expect(find.text(l10n.defaultAppDescriptionWindows), findsOneWidget);
    for (final step in [
      l10n.defaultAppWindowsStep1,
      l10n.defaultAppWindowsStep2,
      l10n.defaultAppWindowsStep3,
      l10n.defaultAppWindowsStep4,
    ]) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.byType(ActionChip), findsNWidgets(11)); // .pdf + .ai .svg + 이미지 8개
    expect(find.text('.pdf'), findsOneWidget);
    expect(find.text('.tiff'), findsOneWidget);

    await tester.tap(find.text(l10n.defaultAppOpenSettingsButton));
    await tester.pump();
    expect(opened, 1);

    await tester.tap(find.text('.svg'));
    await tester.pump();
    expect(copied, '.svg');
    expect(find.text(l10n.defaultAppCopied('.svg')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Windows: 설치 프로그램으로 등록되지 않았으면 알린다', (tester) async {
    await tester.pumpWidget(_host(DefaultAppSection(openSettings: () async => false)));
    final l10n = AppLocalizations.of(tester.element(find.byType(DefaultAppSection)));
    await tester.tap(find.text(l10n.defaultAppOpenSettingsButton));
    await tester.pump();
    expect(find.text(l10n.defaultAppNotRegisteredWindows), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('macOS·Linux: 안내 문단만, 단추와 칩은 없다', (tester) async {
    await tester.pumpWidget(_host(const DefaultAppSection()));
    final l10n = AppLocalizations.of(tester.element(find.byType(DefaultAppSection)));
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    expect(find.text(mac ? l10n.defaultAppMacSteps : l10n.defaultAppLinuxSteps), findsOneWidget);
    expect(find.text(l10n.defaultAppOpenSettingsButton), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  }, variant: TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.linux}));

  testWidgets('모바일: 아무것도 그리지 않는다', (tester) async {
    await tester.pumpWidget(_host(const DefaultAppSection()));
    expect(find.byType(Text), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('Windows 설정 링크: HKLM에 있으면 machine, HKCU에만 있으면 user, 없으면 false', () async {
    Future<ProcessResult> Function(String, List<String>) regWith(String? root) =>
        (exe, args) async => ProcessResult(0, root != null && args[1].startsWith(root) ? 0 : 1, '', '');
    final launched = <Uri>[];
    Future<bool> launch(Uri uri) async {
      launched.add(uri);
      return true;
    }

    expect(await openWindowsDefaultAppsPage(run: regWith('HKLM'), launch: launch), isTrue);
    expect(await openWindowsDefaultAppsPage(run: regWith('HKCU'), launch: launch), isTrue);
    expect(await openWindowsDefaultAppsPage(run: regWith(null), launch: launch), isFalse);
    expect(launched.map((u) => u.toString()), [
      'ms-settings:defaultapps?registeredAppMachine=Daylight%20PDF',
      'ms-settings:defaultapps?registeredAppUser=Daylight%20PDF',
    ]);
  });
}
