import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 파일별 북마크(쪽 번호, 1부터). PDF 안에는 쓰지 않고 설정 파일(`bookmarks` 키)에 경로별로 저장한다:
/// PDFium에는 북마크를 쓰는 API가 없고, 원본을 건드리지 않는 편이 안전하다. 그래서 다른 경로로 저장한 사본에는 따라가지 않는다.
class BookmarkStore {
  static const _key = 'bookmarks';

  Future<Map<String, List<int>>> _all() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries) e.key: [for (final n in e.value as List) n as int],
      };
    } on Object {
      return {}; // 깨진 저장값은 비어 있는 것으로 본다
    }
  }

  Future<void> _save(Map<String, List<int>> all) async {
    final prefs = await SharedPreferences.getInstance();
    all.removeWhere((_, pages) => pages.isEmpty);
    if (all.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(all));
    }
  }

  /// [path] 파일의 북마크 쪽 번호 (오름차순).
  Future<List<int>> load(String path) async => [...?(await _all())[p.normalize(path)]]..sort();

  /// [page]에 북마크가 있으면 지우고 없으면 달아서, 바뀐 목록을 돌려준다.
  Future<List<int>> toggle(String path, int page) async {
    final all = await _all();
    final key = p.normalize(path);
    final pages = {...?all[key]};
    if (!pages.remove(page)) pages.add(page);
    all[key] = pages.toList()..sort();
    await _save(all);
    return all[key]!;
  }

  Future<List<int>> remove(String path, int page) async {
    final all = await _all();
    final key = p.normalize(path);
    all[key] = [...?all[key]]..remove(page);
    await _save(all);
    return all[key]!;
  }
}
