import 'dart:io';

import 'package:path/path.dart' as p;

/// [desired]가 이미 있으면 `이름 (1).확장자`, `이름 (2).확장자`…로 비켜서 덮어쓰지 않는다.
String uniquePath(String desired) {
  if (!_exists(desired)) return desired;
  final dir = p.dirname(desired);
  final base = p.basenameWithoutExtension(desired);
  final ext = p.extension(desired);
  for (var i = 1; ; i++) {
    final candidate = p.join(dir, '$base ($i)$ext');
    if (!_exists(candidate)) return candidate;
  }
}

bool _exists(String path) => FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
