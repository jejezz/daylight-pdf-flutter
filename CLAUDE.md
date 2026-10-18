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
- **pdfrx 함정**: 쪽 크기·회전이 같으면 이미 그린 쪽 이미지를 다시 그리지 않는다(`reloadPages`로는 안 바뀐다). 처음엔
  `annotationRenderingMode`를 번갈아 바꿔 캐시 전체를 비웠지만 주석을 달 때마다 모든 쪽이 깜박였다. 지금은
  `third_party/pdfrx`(2.6.5 사본, 고친 곳은 `DAYLIGHT PATCH` 한 군데, `DAYLIGHT_PATCH.md` 참고)가 다시 읽은 쪽만 "바뀜"으로
  표시해, 새 그림이 준비될 때까지 옛 그림을 보여 주고 바뀐 쪽만 다시 그린다. pdfrx를 올릴 때 이 패치를 다시 적용한다.
  (이 패치를 끄면 `annotation_ui_test`의 회전한 쪽 시험이 실패한다.)
- **큰 문서**: 주석 목록은 건드린 쪽만 다시 읽는다(`AnnotationState.refresh(pages:)`). 복잡한 쪽 300장(347MB)에서 전체 읽기는
  약 12초였다. 저장(`encodePdf`)은 파일 전체를 메모리에 올리므로 파일 크기만큼 메모리를 쓴다 (2GB 문서 ≈ 2GB).
- 시험한 것: macOS의 실제 화면 구동(그리기·메모·형광펜·삭제·나가기 확인), 평평한 쪽과 90° 회전한 쪽에서 그린 위치.
  **못 시험한 것**: 저장 창(네이티브)을 통한 저장 클릭, Windows·Linux.

## 인쇄 (`lib/print/`)

- 보기 화면의 인쇄 단추(⌘P / Ctrl+P) → `showPrintDialog`: 왼쪽에서 설정, 오른쪽에서 가공 결과 미리보기(앞 12쪽만), "인쇄 창 열기"가
  `printing`의 `Printing.layoutPdf`로 **운영체제 인쇄 창**을 연다. 프린터·매수·양면·컬러·용지함은 그 창이 맡고, 앱은 PDF를 찍기 전에
  가공하는 설정만 둔다: 범위(전체/현재 쪽/`1-3, 5, 8-`), 홀수·짝수, 거꾸로, 주석 포함 여부, 크기(맞춤/큰 쪽만 줄임/원래 크기),
  여백, 용지, 쪽 방향에 맞춰 용지 돌리기. 열린 문서를 `encodePdf()`로 넘기므로 저장 안 한 주석도 찍힌다.
- 가공은 `PrintProcessor.build`(PDFium FFI, 벡터 유지): 고른 쪽을 새 문서로 모으고(`pages =`는 저장할 때 모으므로 `encodePdf` 뒤 다시 열어서
  손본다), 주석을 지우거나(`FPDFPage_RemoveAnnot`) 모양(AP)을 만들어 두고, `FPDFPage_TransFormWithClip`으로 내용을 배율+이동하고,
  주석은 영역(Rect)·글자 사각형(QuadPoints)만 같은 행렬로 옮긴다. 쪽 회전(`/Rotate`)은 **그대로 둔다**(풀어서 내용에 녹이면 주석 모양이
  따라 돌지 않는다). 쪽 상자는 용지 크기(90°/270°면 가로세로 바뀜). 배치 계산은 순수 함수 `placePage`(`test/print_layout_test.dart`).
- **PDFium 함정 (실제 앱이 죽었다)**: PDFium의 주석 목록(`CPDF_AnnotList`)을 만드는 호출은 내용이 있는 주석마다 팝업을 만들며 글꼴을 찾는데,
  글꼴 대체 콜백이 pdfrx 작업 스레드에만 등록돼 있어 **메인 스레드에서 부르면 "Cannot invoke native callback from a different
  isolate"로 앱이 죽는다.** 해당: `FPDF_RenderPageBitmap`(주석 포함), `FPDFPage_TransformAnnots`. 그래서 모양을 만드는 그리기는
  `PdfPage.render`(작업 스레드)로 하고, 주석은 `FPDFAnnot_*`(주석 하나씩)로만 만진다. 글자 있는 메모·형광펜 시험이 이를 지킨다.
  또 `FPDFPage_Flatten`은 이 문서에서 빈 내용을 내서 쓰지 않고, `TransFormWithClip`의 자르기 상자는 행렬이 닿기 전 좌표(= 새 쪽 상자 좌표)로 준다.
- 운영체제 창에서 용지를 바꾸면 `onLayout`이 새 크기로 다시 가공한다(`optionsForFormat`).
- 미리보기 `PdfViewer`는 바뀔 때마다 새 키로 만든다(쓰던 뷰어의 문서를 바꾸면 pdfrx가 배치 도중 null 오류).
- 시험한 것: 실제 PDFium으로 쪽 선택·용지·주석 포함 여부·여백·원래 크기·회전(픽셀 확인), 설정 창 구동, macOS 인쇄 창이 가공 결과를
  미리 보여 주는 것. **못 시험한 것**: 실제 프린터 출력(이 맥에 프린터 없음), Windows·Linux 인쇄 창, 다른 뷰어에서 주석이 찍히는지.

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

## 실행 취소와 최근 파일

- **실행 취소(⌘Z / Ctrl+Z, 도구 줄의 "실행 취소")**: `AnnotationState`가 사용자가 한 일마다 한 칸씩 기록한다(여러 줄에 걸친
  형광펜은 한 칸). 새 주석은 PDFium이 그 쪽 목록의 맨 끝에 붙이므로 (쪽, 쪽 안의 번호)로 기억하고, 목록에서 주석을 지우면
  기록의 번호를 당긴다. PDFium 호출은 `AnnotationBackend` 뒤에 있어 `test/annotation_state_test.dart`가 가짜 백엔드로
  기록 로직을 시험한다. 취소해도 저장 파일과 달라지므로 `dirty`는 켜진다.
- **최근 파일**: `RecentFiles`(`lib/home/recent_files.dart`)가 `recent_files` 키에 경로를 저장한다(최신순, 중복 없음, 10개).
  사라진 파일은 읽을 때 걸러 저장소에서도 지운다. 홈은 최근 파일이 있으면 끌어놓기 영역을 한 줄로 줄이고 두 열 격자로
  10개를 한눈에 보여 준다. 경로는 `shortFolder`로 줄여 보이고 전체 경로는 툴팁이다.

## 통합 테스트 요령

- **한 번에 하나의 실행만** 돈다. 두 개를 동시에 돌리면 서로의 앱을 종료시키고 빌드 DB가 잠겨 엉뚱하게 실패한다.
- 화면 좌표를 계산식으로 추정하지 않는다. 쪽 위치는 실제 그려진 화면에서 측정한다(`measurePage`, 순백 바탕 영역).
  창 크기·배치가 바뀌면 추정은 어긋난다.
- 앱을 직접 열어 보기 전에는 `flutter build macos --debug`를 다시 한다 (통합 테스트가 같은 경로의 앱을 테스트용으로 바꾼다).

## 메모 보기·고치기

- 쪽의 메모 아이콘 자리에 투명한 `_NoteHotspot`을 얹는다: 마우스를 올리면 내용이 툴팁으로 뜨고, 누르면 `showNoteDialog`(읽기·고치기·삭제)가
  열린다. 주석 목록의 메모 행을 눌러도 같은 창이 열린다. 메모 위치는 `ReadAnnotation.rect`(PDF 좌표)로 안다.
- **뷰어로 가는 입력을 막지 않는 것이 핵심이다.** `MouseRegion`과 `Tooltip`은 기본값(`opaque: true`)으로 아래 위젯의 입력을
  막아 뷰어가 누르기를 못 받는다. 그래서 올리기는 `MouseRegion(opaque: false)`, 툴팁은 `IgnorePointer` 안에서 직접 띄우고
  (`triggerMode: manual`), 누르기는 `PdfOverlayInteractionRegion`으로 받는다.
- 뷰어는 더블탭과 구분하려고 누른 뒤 약 0.3초 기다린다(프레임 없는 타이머라 테스트에서는 `pump(500ms)`가 필요하다).
- 메모를 고치는 일(`editNote`)은 실행 취소 기록에 넣지 않는다.

## 메모 아이콘 (`assets/annotations/note_icon.svg`)

새 메모는 이 SVG를 **저장하는 PDF 안의 메모 모양(appearance)** 으로 넣는다. 그래서 다른 뷰어(PDFium 계열, macOS PDFKit/미리보기)에서도
같은 아이콘으로 보이고, 주석 종류는 표준 "메모(Text)"라서 다른 뷰어의 메모 동작도 그대로다. 이미 만든 옛 메모는 그대로(뷰어 기본 아이콘).

- **바꾸는 법**: 같은 이름으로 SVG를 교체하고 `flutter test test/svg_appearance_test.dart`로 확인한다(번들 아이콘 시험이 색·위치를 점검).
- **규격**: 정사각형 `viewBox`(예: 100×100, 24×24), 배경 투명. PDF에서는 **24×24pt**로 그려진다. 변환은 `svgToAppearance`.
- **쓸 수 있는 것**: `path`(M L H V C S Q T A Z), `rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`, `g`, `transform`,
  단색 `fill`/`stroke`, `fill-rule`, `stroke-width/linecap/linejoin`. 선형 그라디언트는 도형으로 잘라 띠(최대 24개)로 그려 보존한다.
- **근사하는 것**: 방사형 그라디언트는 평균색 단색, 투명도(`opacity`)는 흰 바탕과 섞은 단색.
- **무시하는 것**: 글자, `<image>`, `<use>`, 클리핑·마스크·필터, 점선. 이것만으로 된 SVG나 깨진 SVG는 메모가 뷰어 기본 아이콘으로 만들어진다.
- 아이콘의 색은 고정이라 팔레트에서 고른 색은 모양에 반영되지 않는다. 팔레트 색을 따르게 하려면 SVG의 그 부분을 `fill="currentColor"`로 쓴다.
- PDFium `FPDFAnnot_SetAP`의 좌표는 **페이지 기준 절대 좌표**다(영역 기준 상대 좌표는 페이지 원점에 그려진다 — 실험으로 확인).
- 이미지(PNG)를 쓰려면 스탬프 주석(`FPDFAnnot_AppendObject`는 스탬프·잉크만 지원)이 되어 다른 뷰어에서 메모 동작을 잃으므로 쓰지 않았다.

## 메모 도구 동작 (실제 앱에서 확인한 것)

- 메모 도구가 켜져 있으면 그리기 입력 층(`DrawLayer`)이 쪽을 덮어 **메모 아이콘에 마우스를 올려도 툴팁이 안 뜨고** 눌러도 읽기 창이 안 열린다.
  그래서 메모를 하나 놓으면 도구가 **저절로 꺼지고**, 도구가 켜진 채 **기존 메모 아이콘을 누르면** 새 메모 대신 그 메모를 연다
  (`noteAt`으로 PDF 좌표가 어느 메모 아이콘 안인지 찾는다). 입력창을 취소하면 도구는 켜진 채 남는다.
- "내용이 안 보인다"는 보고는 실행 파일이 오래된 게 아니라 이 상태(도구가 켜진 채)였다. 오래된 실행 파일인지 의심되면
  `ps -axo pid,lstart,command`로 시작 시각을, 번들 파일의 수정 시각과 마지막 커밋 시각을 비교한다.
