import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_kind.dart';

/// 운영체제가 파일을 이 앱으로 열어 줄 때 그 경로를 받는다.
/// - Android: 다른 앱이 PDF를 열거나 공유하면 `MainActivity`가 앱 캐시로 복사해 그 경로를 보낸다(`initialFile`, `fileOpened`).
/// - macOS: Finder에서 더블클릭·"다음으로 열기"·Dock에 끌어놓기를 하면 `AppDelegate`가 보낸다(`initialFiles`, `filesOpened`).
///   macOS는 명령줄 인자로 파일을 주지 않는다.
/// Windows·Linux는 새 프로세스의 명령줄 인자로 오므로(`filesFromArguments`) 여기서는 아무것도 하지 않는다.
class IncomingFiles {
  IncomingFiles({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('art.zoomon.daylightpdf/incoming');

  final MethodChannel _channel;
  final _controller = StreamController<List<String>>.broadcast();

  static bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  /// 앱이 떠 있는 동안 새로 들어온 파일 경로.
  Stream<List<String>> get opened => _controller.stream;

  /// 앱을 시작하게 만든 파일 (없으면 빈 목록). 시작할 때 한 번만 부른다.
  Future<List<String>> start() async {
    if (!isMobilePlatform && !_isMacOS) return const [];
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (call.method == 'fileOpened' && args is String) _controller.add([args]);
      if (call.method == 'filesOpened' && args is List) _controller.add(args.whereType<String>().toList());
    });
    try {
      if (_isMacOS) {
        final files = await _channel.invokeListMethod<String>('initialFiles');
        return files ?? const [];
      }
      final file = await _channel.invokeMethod<String>('initialFile');
      return file == null ? const [] : [file];
    } on MissingPluginException {
      return const []; // iOS 등 아직 연결하지 않은 플랫폼
    }
  }

  void dispose() => _controller.close();
}
