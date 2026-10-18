import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 모바일에서 연 PDF를 앱 보관함에 복사해 둔다.
///
/// 파일 선택 창이나 다른 앱이 넘겨 주는 파일은 임시(캐시) 복사본이라 시스템이 언제든 지울 수 있다. 그러면 최근 파일을 눌러도 열리지 않는다.
/// 앱 전용 폴더에 복사해 두면 사라지지 않는다. 같은 이름의 파일도 겹치지 않게 열 때마다 새 하위 폴더(시각)에 넣는다.
class OpenedFiles {
  OpenedFiles({Future<Directory> Function()? baseDirectory}) : _baseDirectory = baseDirectory ?? _defaultBase;

  final Future<Directory> Function() _baseDirectory;

  static Future<Directory> _defaultBase() async =>
      Directory(p.join((await getApplicationSupportDirectory()).path, 'opened'));

  /// [path]의 파일을 보관함에 복사하고 복사본의 경로를 돌려준다. 이미 보관함 안에 있으면 그대로 돌려준다.
  /// 복사에 실패하면(저장 공간 부족 등) 원래 경로를 돌려줘서 열기는 된다.
  Future<String> adopt(String path) async {
    try {
      final base = await _baseDirectory();
      if (p.isWithin(base.path, path)) return path;
      // 같은 파일(이름과 내용이 같다)을 또 열면 새 복사본을 만들지 않고 있던 것을 쓴다. 그래야 최근 목록에 같은 파일이 여러 번 나오지 않는다.
      final existing = await _sameCopy(base, path);
      if (existing != null) return existing;
      final folder = Directory(p.join(base.path, DateTime.now().microsecondsSinceEpoch.toString()));
      await folder.create(recursive: true);
      final copy = File(p.join(folder.path, p.basename(path)));
      await File(path).copy(copy.path);
      return copy.path;
    } on FileSystemException {
      return path;
    }
  }

  /// 보관함에 [path]와 이름과 내용이 같은 복사본이 있으면 그 경로 (없으면 null).
  Future<String?> _sameCopy(Directory base, String path) async {
    if (!base.existsSync()) return null;
    final source = File(path);
    final length = await source.length();
    final name = p.basename(path);
    for (final entry in base.listSync()) {
      if (entry is! Directory) continue;
      final candidate = File(p.join(entry.path, name));
      if (!candidate.existsSync() || await candidate.length() != length) continue;
      if (await _sameBytes(source, candidate)) return candidate.path;
    }
    return null;
  }

  /// 두 파일의 내용이 같은지. 덩어리로 읽어 다른 곳이 나오면 바로 멈춘다 (큰 PDF를 통째로 올리지 않는다).
  Future<bool> _sameBytes(File a, File b) async {
    final fa = await a.open(), fb = await b.open();
    try {
      while (true) {
        final x = await fa.read(65536), y = await fb.read(65536);
        if (x.length != y.length) return false;
        if (x.isEmpty) return true;
        for (var i = 0; i < x.length; i++) {
          if (x[i] != y[i]) return false;
        }
      }
    } finally {
      await fa.close();
      await fb.close();
    }
  }

  /// 보관함에서 [keep]에 없는 파일을 지운다 (최근 목록에서 빠진 파일이 쌓이지 않게).
  Future<void> prune(Iterable<String> keep) async {
    final base = await _baseDirectory();
    if (!base.existsSync()) return;
    final keepSet = keep.map(p.normalize).toSet();
    for (final entry in base.listSync()) {
      if (entry is! Directory) continue;
      final files = entry.listSync().whereType<File>().toList();
      if (files.every((f) => !keepSet.contains(p.normalize(f.path)))) {
        try {
          entry.deleteSync(recursive: true);
        } on FileSystemException {
          // 지우지 못해도 다음 기회에 지운다
        }
      }
    }
  }
}
