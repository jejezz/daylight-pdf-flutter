# Daylight PDF

PDF 변환, 보기, 주석(메모 포함), 페이지 조작을 한곳에서 하는 데스크톱 앱
(macOS/Windows/Linux, Flutter). 기존 PDF의 텍스트를 직접 수정·생성하는 기능은
범위 밖이다. 되는 것은 전부 되게 만들고, 안 되는 것은 억지로 되게 하지 않는다.

## 공통 규약

릴리스·버전·패키징·정보 창·아이콘·라이선스·UI/UX·글꼴·언어·테마는
https://github.com/jejezz/application-release-templates/tree/main/conventions
규약을 따른다. 이 앱에 적용된 규약 버전: conventions-v1

- 식별자는 `art.zoomon.daylightpdf`, 표시 이름은 `Daylight PDF`다.
  `AppInfo.xcconfig`의 `PRODUCT_NAME`과 `lib/app_identity.dart`는 같게 둔다.
- 버전은 `scripts/bump-version.sh`로 올리고, 병합된 `main`에 태그를 단다.
- `lib/about/`·`lib/settings/`의 공통 파일은 템플릿과 같게 둔다.
- 테마·언어는 `AppSettings`(키 `theme_mode`, `app_locale`)로 다룬다.
- README는 `README.md`(영어)와 `README.ko.md`(한국어)를 같은 내용으로 유지하고
  `python3 tool/readme/check_readme.py`로 검사한다.
- 아이콘은 고양이 + 소품 배지다. 소품은 `assets/icon/source_glyph.png`(지금은 임시 글리프),
  설정은 `assets/icon/cat.json`(hue 0 고정: 기존 앱과 20° 이상 떨어짐)이고
  `python3 tool/icon/generate_icons.py "$HOME/MyFiles/이미지/icons8-grinning-cat-1024.png"`로
  다시 만든다. 고양이 원본은 저장소에 커밋하지 않는다. 손으로 고치지 않는다.

## 범위

- 변환: 이미지(PNG/JPG/HEIC) → PDF, SVG → PDF, PDF 호환 `.ai` → PDF, PDF → 이미지,
  일괄 변환. PDF 호환 옵션이 꺼진 `.ai`는 안내 메시지로 처리한다.
- 보기, 주석(하이라이트·밑줄·도형·손글씨), 메모(PDF 표준 주석), 페이지 조작.
- PDF 엔진은 인터페이스 뒤에 두어 교체 가능하게 한다.

## 테스트

- `flutter test`: 순수 Dart·위젯 테스트. 네이티브 PDFium은 여기서 못 불러온다.
- `integration_test/`: PDFium이 필요한 테스트는 실제 앱에서 돈다. **파일 하나씩** 돌린다
  (`flutter test integration_test/convert_test.dart -d macos`). 여러 파일을 한 번에 돌리면 앞 앱이
  덜 닫혀 "Unable to start the app"으로 실패할 수 있다.
- 변환 실패는 `ConversionException(kind)`로 던지고 문구는 UI가 ARB에서 고른다.

## 변환 한계 (사용자에게 알려야 하는 것)

- `.ai`는 "PDF 호환 파일 만들기"로 저장된 것만 변환한다. 아니면 `notPdfCompatible`로 안내한다.
- SVG 글자에 한글 등 Latin-1 밖 문자가 있으면 대체 글꼴 SeoulNamsan을 PDF에 넣는다(`SvgToPdf.convert`의
  `loadFallbackFonts`). 이 글꼴에 없는 문자(예: é ñ ü)는 □로 나오고, 이때 SVG 글자 전체가 SeoulNamsan이 된다.
- 이미지는 PNG/JPG/BMP/GIF/WebP/TIFF. HEIC는 지원하지 않는다(건너뛰고 알림).

## 페이지 도구 (`lib/pages/`)

- 합치기·나누기·추출·재배열·회전·삭제는 모두 `PageOps.build(List<PageRef>, 출력)` 하나로 귀결된다.
  원본은 바꾸지 않고, 출력은 문서를 모두 닫은 뒤 `.tmp`에 쓰고 이름을 바꿔 넣는다(원본 덮어쓰기도 안전).
- 쪽 범위 문법은 `page_ranges.dart` (`1-3, 5, 8-`), 오류는 `ConversionErrorKind.invalidPageRange`.
- 앱 바의 `FocusTint`가 `window_manager`를 부르므로, 통합 테스트에서 앱 바가 있는 화면을 띄울 때는
  `windowManager.ensureInitialized()`를 먼저 해야 한다(안 하면 플러그인이 앱을 죽인다).
