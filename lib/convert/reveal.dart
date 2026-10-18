import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

/// [path]가 든 폴더를 파일 관리자(Finder, 탐색기)로 연다. 열 수 없으면 조용히 넘어간다 (결과 파일은 이미 저장돼 있다).
Future<void> revealInFolder(String path) async {
  try {
    await launchUrl(Uri.directory(p.dirname(path)));
  } on Object {
    // 파일 관리자를 못 열어도 변환 결과에는 영향이 없다.
  }
}

/// [path]를 기본 앱으로 연다.
Future<void> openResult(String path) async {
  try {
    await launchUrl(Uri.file(path));
  } on Object {
    // 연결된 앱이 없으면 그냥 넘어간다.
  }
}
