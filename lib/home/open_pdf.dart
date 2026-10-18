import 'package:flutter/material.dart';

import '../platform/platform_kind.dart';
import '../viewer/viewer_screen.dart';
import 'opened_files.dart';
import 'recent_files.dart';

/// PDF를 열어 보기 화면으로 간다: (모바일이면) 앱 보관함에 복사하고, 최근 파일 맨 앞에 올린 뒤, 보기 화면을 띄운다.
/// 보기 화면에서 돌아오면 끝난다.
Future<void> openPdf(NavigatorState navigator, String path, {required RecentFiles recents, OpenedFiles? opened}) async {
  var target = path;
  final store = isMobilePlatform ? (opened ?? OpenedFiles()) : null;
  if (store != null) target = await store.adopt(path);
  await recents.add(target);
  if (store != null) await store.prune(await recents.load());
  await navigator.push(MaterialPageRoute<void>(builder: (_) => ViewerScreen(path: target)));
}
