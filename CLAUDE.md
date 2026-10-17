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

## 주석 (`lib/engine/annotations/`) — 5단계 스파이크 결과

PDFium FFI(`pdfium_dart`)로 `PdfiumAnnotations.add/read/remove`를 구현했다. 문서는 pdfrx의 `useNativeDocumentHandle`로
빌려 쓰고, 저장은 평소처럼 `encodePdf()`다. **되는 것** (PDFium과 macOS PDFKit에서 종류·위치·색·한글 내용·표시 확인):

- 형광펜(곱하기 혼합이라 글자를 가리지 않음), 밑줄, 스티커 메모(한글 내용 보존), 손글씨, 사각형, 원, 삭제(저장 후 유지).

**안 하는 것**: FreeText(화면에 직접 보이는 글상자). PDFium이 외형을 만들어 주지 않아 직접 외형 스트림과 글꼴을
써야 하는데, 되는 방법을 확인하지 못했다. 메모는 스티커 메모로 대신한다. 미리보기·PDFKit·PDFium 외의 뷰어
(Acrobat, 브라우저 등)에서의 표시는 시험하지 못했다.

규칙: 좌표는 PDF 사용자 공간(원점 왼쪽 아래, pt). 색은 0xAARRGGBB이고 알파는 불투명도가 된다.

## 주석 UI (`lib/viewer/`) — 6단계

- 형광펜·밑줄은 "글자를 마우스로 고르고 도구 모음 버튼"(`lineBoxes`가 선택한 글자를 줄별 상자로 바꾼다).
  메모(클릭)·손글씨·사각형·원은 도구 모드: `DrawLayer`가 뷰어 위에서 마우스 입력을 받아
  `controller.getPdfPageHitTestResult`로 쪽과 PDF 좌표(쪽 회전 반영)로 바꾼다. 그리는 도구가 켜지면 화면 끌기만 꺼진다.
- 주석은 열린 문서(메모리)에 바로 쓰이고, 저장 단추가 `encodePdf()`를 새 파일로 쓴다. 저장 안 한 주석이 있으면
  나갈 때 묻는다(`PopScope`).
- **pdfrx 함정**: 쪽 크기·회전이 같으면 본문의 이미 그린 쪽 이미지를 다시 그리지 않는다(`reloadPages`로는 안 바뀐다).
  그래서 `AnnotationState.revision`의 홀짝으로 `annotationRenderingMode`를 바꿔 이미지 캐시를 비우게 한다
  (`viewer_screen.dart`). 두 모드 모두 주석을 그리지만 폼 입력란이 있는 PDF는 모드에 따라 강조색이 미세하게 다르다.
- 시험한 것: macOS의 실제 화면 구동(그리기·메모·형광펜·삭제·나가기 확인), 평평한 쪽과 90° 회전한 쪽에서 그린 위치.
  **못 시험한 것**: 저장 창(네이티브)을 통한 저장 클릭, Windows·Linux.

## 화면 구성과 공통 위젯 (`lib/widgets/`)

규약의 Saturn 디자인 언어(카드 24/20, 상태 알약, 간격 4의 배수)를 화면에 드러내는 앱 전용 위젯이다.
`lib/theme/`는 템플릿 공통 파일이라 건드리지 않고, 새 모양은 여기서 만든다.

- `GlassCard`(면 + 1px 테두리, `selected`/`onTap`), `StatusPill`(상태 알약, 라이트에선 글자용 색 변형),
  `DropZone`(점선 끌어놓기 영역: 빈 상태용), `DropArea`(내용이 있는 화면 위의 끌어놓기: 점선 없이 강조만),
  `ToolChip`(아이콘 + 글자 도구 버튼, 좁으면 아이콘만), `PageThumbnail`(쪽 모양에 맞는 썸네일).
- 화면 패턴: 빈 상태는 큰 `DropZone`, 내용이 있으면 `DropArea` + 카드/격자. 도구 줄은 `ToolChip`으로 이름을
  함께 보인다(툴팁은 항상 유지). 도구 이름과 같은 글자가 도구 줄과 목록에 같이 있으면 테스트는 목록 위젯 안으로
  범위를 좁혀 찾는다.
- 화면 확인은 라이트·다크 모두, 1200×720에서 한다.
