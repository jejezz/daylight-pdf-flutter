import 'dart:convert';
import 'dart:io';

import 'package:daylight_pdf/convert/convert_screen.dart';
import 'package:daylight_pdf/convert/hwp_runner.dart';
import 'package:daylight_pdf/convert/hwp_to_pdf.dart';
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
      await _app(const ConvertScreen(initialPaths: ['/x/photo.heic', '/x/design.psd']), const Locale('en')),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Skipped 2 unsupported files'), findsOneWidget);
    expect(find.text('Drop images or PDFs to convert'), findsOneWidget);
  });

  group('HWP', () {
    late Directory dir;
    late String hwp;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('hwp_screen');
      hwp = '${dir.path}/보고서.hwp';
      File(hwp).writeAsBytesSync([1]);
    });
    tearDown(() {
      HwpToPdf.runnerForTest = null;
      dir.deleteSync(recursive: true);
    });

    Future<void> convert(WidgetTester tester, Locale locale, HwpProcessRunner runner) async {
      HwpToPdf.runnerForTest = runner;
      await tester.pumpWidget(await _app(ConvertScreen(initialPaths: [hwp]), locale));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    HwpProcessRunner ok(List<String> unavailable) => (exe, args, {required environment, required timeout}) async {
      File(args[args.indexOf('-o') + 1]).writeAsBytesSync(utf8.encode('%PDF-1.7'));
      return HwpProcessResult(
        exitCode: 0,
        stdout: jsonEncode({
          'nativeFontSupply': {'unavailable': unavailable},
        }),
      );
    };

    testWidgets('글꼴을 바꿨으면 완료 줄 아래에 경고가 보인다 (ko)', (tester) async {
      await convert(tester, const Locale('ko'), ok(['한양신명조', '함초롬바탕']));
      expect(find.text('보고서.hwp'), findsOneWidget);
      expect(find.text('보고서.pdf'), findsOneWidget);
      expect(find.textContaining('원본 글꼴 2개를 이 컴퓨터에서 찾지 못해'), findsOneWidget);
      expect(find.textContaining('원본과 다를 수 있어요'), findsOneWidget);
    });

    testWidgets('글꼴을 다 찾았으면 경고가 없다 (en)', (tester) async {
      await convert(tester, const Locale('en'), ok([]));
      expect(find.text('보고서.pdf'), findsOneWidget);
      expect(find.textContaining('not installed on this computer'), findsNothing);
    });

    testWidgets('변환기를 실행할 수 없으면 안내 문구가 보인다 (ko)', (tester) async {
      await convert(
        tester,
        const Locale('ko'),
        (exe, args, {required environment, required timeout}) => throw const ProcessException('rhwp', []),
      );
      expect(find.textContaining('문서 변환기를 실행할 수 없어요'), findsOneWidget);
      expect(File('${dir.path}/보고서.pdf').existsSync(), isFalse);
    });

    testWidgets('영어 경고 문구는 복수형을 맞춘다', (tester) async {
      await convert(tester, const Locale('en'), ok(['A']));
      expect(find.textContaining('1 font from the original is not installed'), findsOneWidget);
    });
  });
}
