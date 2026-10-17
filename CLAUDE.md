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
