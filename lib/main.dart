// From jejezz/application-release-templates common/ @ conventions-v1.
//
// 새 앱의 시작점. 규약이 요구하는 연결을 한곳에 모았다:
//   창 크기(window_manager) · 추가 라이선스 · 설정 로드 · 라이트/다크 ·
//   언어 해석 · macOS 앱 메뉴 About · 앱 바 [테마 | 언어 | 정보] · 빈 상태.
// 기존 앱에는 통째로 덮어쓰지 말고 필요한 부분만 옮긴다.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'about/about_dialog.dart';
import 'about/app_menu_bar.dart';
import 'about/extra_licenses.dart';
import 'app_identity.dart';
import 'home/home_screen.dart';
import 'home/open_files.dart';
import 'home/recent_files.dart';
import 'platform/incoming_files.dart';
import 'platform/startup_error_app.dart';
import 'platform/startup_log.dart';
import 'l10n/app_localizations.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';
import 'update/update_scope.dart';
import 'update/update_service.dart';
import 'window/window_placement.dart';

final bool _isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // 창은 준비를 마친 뒤에야 보이므로, 그 앞에서 실패하면 창 없이 프로세스만 남는다(Windows 10 보고).
  // 단계마다 기록하고(StartupLog), 멈춘 단계는 제한 시간 뒤 건너뛰고, 창은 어떻게든 띄운다.
  final log = StartupLog.start(args: args);
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    log.error('flutter', details.exception, details.stack);
    previousOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.error('uncaught', error, stack);
    return false;
  };

  try {
    registerExtraLicenses();
  } on Object catch (e, s) {
    log.error('licenses', e, s);
  }
  // 실패하거나 멈춰도 넘어간다: 문서를 열 때 pdfrx가 다시 초기화를 시도한다.
  await log.step('pdfrx', pdfrxFlutterInitialize, timeout: const Duration(seconds: 20), fallback: () {});

  Future<void> Function()? showWindow;
  if (_isDesktop) {
    await log.step('window manager', windowManager.ensureInitialized, timeout: const Duration(seconds: 10), fallback: () {});
    showWindow = await log.step(
      'window placement',
      () => _prepareWindow(newWindow: args.contains('--new-window'), log: log),
      timeout: const Duration(seconds: 10),
      fallback: () => () => _showNow(log),
    );
  }

  try {
    final settings = await log.step('settings', AppSettings.load, timeout: const Duration(seconds: 10));
    // 데스크톱이 아니거나 UPDATE_SERVER 가 비어 있으면 null — 업데이트 확인 없음.
    final updates = await log.step('updates', UpdateService.create, timeout: const Duration(seconds: 10), fallback: () => null);
    // UpdateScope 는 MaterialApp 위에 둔다 — 정보 창이 이것을 읽어 "업데이트 확인" 단추를 붙인다.
    runApp(
      UpdateScope(
        service: updates,
        child: App(settings: settings, updates: updates, initialFiles: _isDesktop ? filesFromArguments(args) : const []),
      ),
    );
  } on Object catch (e) {
    runApp(StartupErrorApp(error: e, logPath: log.file?.path));
  }

  if (showWindow != null) {
    final show = showWindow;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(show()));
  }
}

/// 배치를 기다리지 않고 바로 창을 띄운다(배치 단계가 실패했을 때).
Future<void> _showNow(StartupLog log) async {
  try {
    await windowManager.show();
    await windowManager.focus();
    log.write('window shown (without placement)');
  } on Object catch (e, s) {
    log.error('show', e, s);
  }
}

/// 다음 프레임이 그려질 때까지 기다린다.
Future<void> _nextFrame() {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
  WidgetsBinding.instance.scheduleFrame();
  return completer.future;
}

/// ui-ux.md §5: 최소 크기는 960×600 이하 (1366×768 노트북).
/// 시작 위치는 WindowPlacement — 모니터마다 배율이 다른 Windows 듀얼
/// 모니터에서 center: true/저장 좌표 복원이 창을 화면 밖에 놓는다.
/// 배치가 끝나고 첫 프레임이 그려진 뒤에 show() 를 불러야 깜빡이지 않는다 (§5).
Future<Future<void> Function()> _prepareWindow({bool newWindow = false, required StartupLog log}) async {
  const windowSize = Size(1200, 720);
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
  final placed = Completer<void>();
  await windowManager.waitUntilReadyToShow(options, () async {
    try {
      await placement?.placeInitially();
    } on Object catch (e, s) {
      log.error('place window', e, s);
    }
    if (newWindow) {
      // 다른 창이 이미 떠 있다: 같은 자리에 겹치지 않게 조금 어긋나게 놓는다.
      try {
        final at = await windowManager.getPosition();
        await windowManager.setPosition(at + const Offset(32, 32));
      } on Object {
        // 못 옮기면 같은 자리에 뜬다
      }
    }
    placed.complete();
  });
  return () async {
    try {
      // 배치 콜백이 오지 않거나 실패해도 창은 띄운다.
      await placed.future.timeout(const Duration(seconds: 5));
    } on TimeoutException catch (e) {
      log.error('window placement callback', e);
    }
    try {
      await _nextFrame().timeout(const Duration(seconds: 5));
      await windowManager.show();
      await windowManager.focus();
      placement?.attach();
      log.write('window shown');
    } on Object catch (e, s) {
      log.error('show', e, s);
    }
  };
}

class App extends StatefulWidget {
  const App({super.key, required this.settings, this.updates, this.initialFiles = const []});

  final AppSettings settings;
  final UpdateService? updates;

  /// 명령줄로 받은 파일 경로 (Windows·Linux, macOS의 `--new-window`). 있으면 시작하자마자 연다.
  final List<String> initialFiles;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _incoming = IncomingFiles();
  StreamSubscription<List<String>>? _incomingSubscription;

  /// 운영체제가 파일을 이 앱으로 열었을 때: PDF 한 개면 보기 화면(모바일은 앱 보관함에 복사), 그 밖에는 변환 화면.
  void _openIncoming(List<String> paths) {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && paths.isNotEmpty) openFiles(navigator, paths, recents: RecentFiles());
  }

  @override
  void initState() {
    super.initState();
    _incomingSubscription = _incoming.opened.listen(_openIncoming);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final received = await _incoming.start();
      _openIncoming(received.isNotEmpty ? received : widget.initialFiles);
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
