import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 최근에 연 PDF 목록: 최신순, 같은 파일은 한 번만, 최대 [limit]개. 설정 파일에 경로만 저장한다.
class RecentFiles {
  RecentFiles({this.limit = 10});

  static const _key = 'recent_files';

  final int limit;

  /// 저장된 목록 그대로 (파일이 있는지는 보지 않는다).
  Future<List<String>> load() async => (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];

  /// 지금도 있는 파일만. 사라진 파일은 저장소에서도 지운다 (지웠거나 옮긴 파일이 목록에 남지 않게).
  Future<List<String>> loadExisting() async {
    final all = await load();
    final existing = all.where((path) => File(path).existsSync()).toList();
    if (existing.length != all.length) await _save(existing);
    return existing;
  }

  /// [path]를 맨 앞에 올린다 (이미 있으면 옮기고, [limit]을 넘는 옛 항목은 버린다).
  Future<void> add(String path) async {
    final normalized = p.normalize(path);
    final list = [normalized, ...(await load()).where((x) => !p.equals(x, normalized))];
    await _save(list.take(limit).toList());
  }

  Future<void> remove(String path) async => _save([
    for (final x in await load())
      if (!p.equals(x, path)) x,
  ]);

  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);

  Future<void> _save(List<String> list) async => (await SharedPreferences.getInstance()).setStringList(_key, list);
}

/// 목록에 보여 줄 폴더 표시: 홈 폴더는 `~`로 줄이고, 세 단계보다 깊으면 마지막 두 폴더만 `…/`로 시작해서 보여 준다.
/// ([home]은 테스트용으로 바꿀 수 있고, 기본은 환경 변수의 홈 폴더.)
String shortFolder(String filePath, {String? home}) {
  final context = p.context;
  var dir = context.dirname(filePath);
  final homeDir = home ?? Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (homeDir != null && homeDir.isNotEmpty && (context.equals(dir, homeDir) || context.isWithin(homeDir, dir))) {
    dir = '~${dir.substring(homeDir.length)}';
  }
  final parts = context.split(dir).where((x) => x != context.separator && x.isNotEmpty).toList();
  if (parts.length <= 3) return dir;
  return '…/${parts.sublist(parts.length - 2).join(context.separator)}';
}
