/// 다른 화면(보기)이 열어 둔 PDF를 페이지 도구가 같은 이름으로 덮어쓸 수 있게, 저장하는 동안 그 파일을 놓아 달라고 부탁하는 창구.
/// Windows는 열려 있는 파일 위로 이름을 바꿀 수 없기 때문이다.
abstract interface class SourceHolder {
  /// 열어 둔 파일의 경로.
  String get path;

  /// 파일을 놓는다. 놓을 수 없으면(저장하지 않은 주석이 있다 등) false.
  Future<bool> release();

  /// 저장이 끝났다(성공이든 실패든): 파일을 다시 열어 새 내용을 읽는다.
  void reacquire();
}

/// [holder]가 [target]을 붙들고 있나.
bool holdsTarget(SourceHolder? holder, String target, bool Function(String a, String b) same) =>
    holder != null && same(holder.path, target);
