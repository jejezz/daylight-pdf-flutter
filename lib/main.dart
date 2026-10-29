// From jejezz/application-release-templates common/ @ conventions-v1.
//
// 새 앱의 시작점. 규약이 요구하는 연결을 한곳에 모았다:
//   창 크기(window_manager) · 추가 라이선스 · 설정 로드 · 라이트/다크 ·
//   언어 해석 · macOS 앱 메뉴 About · 앱 바 [테마 | 언어 | 정보] · 빈 상태.
// 기존 앱에는 통째로 덮어쓰지 말고 필요한 부분만 옮긴다.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'about/about_dialog.dart';
import 'about/app_menu_bar.dart';
import 'about/extra_licenses.dart';
import 'app_identity.dart';
import 'home/home_screen.dart';
import 'home/open_pdf.dart';
import 'home/recent_files.dart';
import 'platform/incoming_files.dart';
import 'l10n/app_localizations.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';
import 'update/update_scope.dart';
import 'update/update_service.dart';
import 'window/window_placement.dart';

final bool _isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// 명령줄 인자(Windows·Linux에서 PDF를 더블클릭하거나 "연결 프로그램"으로 열면 경로가 온다)에서 열 PDF를 고른다.
@visibleForTesting
String? pdfFromArguments(List<String> args) {
  for (final arg in args) {
    if (arg.toLowerCase().endsWith('.pdf') && File(arg).existsSync()) return arg;
  }
  return null;
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  registerExtraLicenses();
  await pdfrxFlutterInitialize();

  if (_isDesktop) {
    await windowManager.ensureInitialized();
    // ui-ux.md §5: 최소 크기는 960×600 이하 (1366×768 노트북).
    const windowSize = Size(1200, 720);
    // 시작 위치는 WindowPlacement — 모니터마다 배율이 다른 Windows 듀얼
    // 모니터에서 center: true/저장 좌표 복원이 창을 화면 밖에 놓는다.
    WindowPlacement? placement;
    if (WindowPlacement.enabled) {
      placement = WindowPlacement(await SharedPreferences.getInstance(), defaultSize: windowSize);
    }
    final options = WindowOptions(
      size: windowSize,
      minimumSize: const Size(960, 600),
      center: placement == null,
      title: AppIdentity.displayName,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await placement?.placeInitially();
      placement?.attach();
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final settings = await AppSettings.load();
  // 데스크톱이 아니거나 UPDATE_SERVER 가 비어 있으면 null — 업데이트 확인 없음.
  final updates = await UpdateService.create();
  // UpdateScope 는 MaterialApp 위에 둔다 — 정보 창이 이것을 읽어 "업데이트 확인" 단추를 붙인다.
  runApp(
    UpdateScope(
      service: updates,
      child: App(settings: settings, updates: updates, initialFile: _isDesktop ? pdfFromArguments(args) : null),
    ),
  );
}

class App extends StatefulWidget {
  const App({super.key, required this.settings, this.updates, this.initialFile});

  final AppSettings settings;
  final UpdateService? updates;

  /// 명령줄로 받은 PDF 경로 (데스크톱). 있으면 시작하자마자 연다.
  final String? initialFile;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _incoming = IncomingFiles();
  StreamSubscription<String>? _incomingSubscription;

  /// 다른 앱이 PDF를 이 앱으로 열었을 때(Android): 앱 보관함에 복사하고 보기 화면으로 간다.
  void _openIncoming(String path) {
    final navigator = _navigatorKey.currentState;
    if (navigator != null) openPdf(navigator, path, recents: RecentFiles());
  }

  @override
  void initState() {
    super.initState();
    _incomingSubscription = _incoming.opened.listen(_openIncoming);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final first = await _incoming.start() ?? widget.initialFile;
      if (first != null) _openIncoming(first);
    });
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_syncWindowBrightness);
    _syncWindowBrightness();
    widget.updates?.startAutomaticCheck(_navigatorKey);
  }

  @override
  void dispose() {
    _incomingSubscription?.cancel();
    _incoming.dispose();
    widget.settings.removeListener(_syncWindowBrightness);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱에서 다크를 골라도 OS가 라이트면 제목 표시줄은 밝게 남는다 (theming.md §4).
  @override
  void didChangePlatformBrightness() => _syncWindowBrightness();

  void _syncWindowBrightness() {
    if (!_isDesktop || Platform.isLinux) return;
    final brightness = switch (widget.settings.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    windowManager.setBrightness(brightness);
  }

  void _showAbout() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    final l10n = AppLocalizations.of(context);
    showAppAboutDialog(
      context,
      tagline: l10n.aboutTagline,
      description: l10n.aboutDescription,
      onCheckForUpdates: widget.updates == null ? null : () => widget.updates!.checkManually(context),
    );
  }

  void _checkForUpdates() {
    final context = _navigatorKey.currentContext;
    if (context != null) widget.updates?.checkManually(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: widget.settings,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          navigatorObservers: [homeRouteObserver],
          title: AppIdentity.displayName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(dense: _isDesktop, palette: widget.settings.accentPalette),
          darkTheme: AppTheme.dark(dense: _isDesktop, palette: widget.settings.accentPalette),
          themeMode: widget.settings.themeMode,
          locale: widget.settings.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: AppSettings.resolveLocale,
          builder: (context, child) => AppMenuBar(
            onAbout: _showAbout,
            onCheckForUpdates: widget.updates == null ? null : _checkForUpdates,
            child: child!,
          ),
          home: HomeScreen(onAbout: _showAbout),
        ),
      ),
    );
  }
}
