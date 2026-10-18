import 'dart:async';

import 'package:flutter/services.dart';

import 'platform_kind.dart';

/// 다른 앱이 PDF를 이 앱으로 열거나 공유했을 때 그 파일을 받는다 (Android). 받은 파일은 앱 캐시의 경로로 전달된다.
/// Android의 `MainActivity`가 보내 주며, 그 밖의 플랫폼에서는 아무것도 하지 않는다.
class IncomingFiles {
  IncomingFiles({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('art.zoomon.daylightpdf/incoming');

  final MethodChannel _channel;
  final _controller = StreamController<String>.broadcast();

  /// 앱이 떠 있는 동안 새로 들어온 PDF 경로.
  Stream<String> get opened => _controller.stream;

  /// 앱을 시작하게 만든 PDF가 있으면 그 경로 (없으면 null). 시작할 때 한 번만 부른다.
  Future<String?> start() async {
    if (!isMobilePlatform) return null;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'fileOpened' && call.arguments is String) _controller.add(call.arguments as String);
    });
    try {
      return await _channel.invokeMethod<String>('initialFile');
    } on MissingPluginException {
      return null; // iOS 등 아직 연결하지 않은 플랫폼
    }
  }

  void dispose() => _controller.close();
}
