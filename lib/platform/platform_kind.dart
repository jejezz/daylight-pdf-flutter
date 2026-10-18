import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

/// 폰·태블릿 앱인지 (Android, iOS). 화면과 동작을 터치용으로 바꾸는 기준이다.
bool get isMobilePlatform =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
