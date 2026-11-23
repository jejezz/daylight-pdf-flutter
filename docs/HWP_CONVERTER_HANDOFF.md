# HWP → PDF 변환기 인수인계 노트

이 브랜치(`archive/hwp-to-pdf`)는 Daylight PDF에 HWP 변환을 넣었던 시점(PR #30, 머지 `3ae1e7f`)의 전체 상태다.
**PDF 리더기에 넣는 것은 바람직하지 않다고 판단해 `main`에서는 되돌렸다.** 별도 앱·도구를 만들 때 출발점으로 쓴다.
(이 노트는 이 브랜치에만 있다. 앱의 규약·범위는 `CLAUDE.md`를 따른다.)

## 어디에 무엇이 있나

| 경로 | 내용 |
|---|---|
| `lib/convert/hwp_to_pdf.dart` | `HwpToPdf`: 명령줄·환경변수 만들기, `.tmp`에 쓴 뒤 이름 바꾸기, 오류 매핑, 못 찾은 글꼴 읽기, OS별 변환기 경로 |
| `lib/convert/hwp_runner.dart` | 프로세스 실행(셸 없음, 제한 시간) — 시험에서 가짜로 바꿀 수 있는 `HwpProcessRunner` |
| `lib/convert/conversion_error.dart` · `conversion_queue.dart` · `error_text.dart` · `convert_screen.dart` | `ConversionWarning`, `ConversionJob.warnings`, 완료 줄 아래 경고 줄(`_WarningLine`) |
| `lib/l10n/app_*.arb` | `errConverterMissing`, `errConversionTimeout`, `warnFontsSubstituted`, `warnFontsDetail` |
| `third_party/rhwp/` | `rhwp.lock`(버전·해시 고정), README |
| `tool/fetch_rhwp.sh` · `tool/package_rhwp.sh` | 고정된 빌드를 받아 해시 확인 후 풀기 / 압축 (로컬에서 시험함) |
| `.github/workflows/build-rhwp.yml` | OS별 최소 빌드 + 프리릴리스 게시(수동 실행) |
| `test/hwp_to_pdf_test.dart` · `integration_test/hwp_test.dart` · `integration_test/fixtures/hwp/` | 단위·통합 시험과 rhwp 저장소의 MIT 예제 2개 |

## 알아낸 것

- **엔진**: [rhwp](https://github.com/edwardkim/rhwp) 0.9.1(MIT, crates.io에 있음). HWP 5.0·HWPX·HML과 "일부" HWP 3.0을 읽는다. `rhwp export-pdf <입력> -o <출력> --json`.
  종료 코드: 암호 문서 2(stderr에 "비밀번호"), 읽을 수 없음 1.
- **품질**: 시료 12개(HWP5·HWPX·HWP3, 최대 151쪽) 모두 변환됐고, 참조 PDF가 있는 5개는 쪽 수가 같았다. 표·다단·머리말·그림이 거의 같게 나왔다.
  글자 폭을 원본 기준으로 맞춰서(`preserveSourceMetrics`) 글꼴이 바뀌어도 줄바꿈이 크게 틀어지지 않았다.
- **글꼴**: 실행 파일에는 글꼴이 거의 없다. 처음 쓸 때 CDN에서 약 60MB를 받아 `%LOCALAPPDATA%\rhwp\webfonts`에 캐시한다.
  `RHWP_WEBFONT_OFFLINE=1` + 비어 있는 `RHWP_WEBFONT_CACHE`로 내려받기를 막고 `--fallback-serif/sans/mono "<설치된 글꼴>"`을 주면 OS 글꼴만으로 변환된다(Windows 확인).
  못 찾은 글꼴 목록은 `--json`의 `nativeFontSupply.unavailable`에 나온다(항목 뒤 ": 사유"가 붙고 중복이 있다; 문서에서 온 값이라 신뢰하지 말 것).
- **크기**: 공식 배포판 `rhwp.exe`는 77.8MB. `cargo build --release --bin rhwp --no-default-features --features wasm-api`(PDF 가져오기·Skia 제외)는 45.7MB(압축 16.8MB)이고
  비교한 4개 파일의 출력은 바이트까지 같았다. Windows에서 빌드 약 25분.
- **속도**: 기본(`svg`) backend는 35쪽 88초, 46쪽 162초, 151쪽 239초(작은 문서 2~10초). `--backend direct`는 2~20초지만 파일이 30~112MB가 되고 그러데이션 같은 일부 문서에서 실패한다.
- **수식**: 기본 backend에서 수식 글자가 깨진다(OS 글꼴만 써도 같음, 글꼴 문제가 아님). `direct`에서는 맞게 그려졌다. 시료가 한 개뿐이라 원인은 못 정했다.

## 만든 CI의 상태

- `build-rhwp.yml` 첫 실행(2026-11-20, run 44698974706): **Windows·Linux·macOS arm64·macOS x64(교차 컴파일) 빌드 4개 모두 성공.**
- `package` 작업은 실패했다. 로그의 마지막 오류: `gh release create ... dist/*`가 `SHA256SUMS.txt`를 올리다 `HTTP 400: Bad Content-Length`.
  실패한 시도는 릴리스·태그를 남기지 않았다. 원인은 확인하지 못했다. 짐작 둘: ① 릴리스를 만든 뒤 `gh release upload`로 파일을 따로 올리기, ② 해시 파일을 파일로 만들 때 `tee`를 거치지 않기. 둘 다 시험하지 않았다.
- 그래서 **`lipo` universal 합치기, 서명, 압축 결과의 실제 동작은 확인하지 못했다**(앞 단계가 성공했는지는 로그로 확인하지 않았다). `release.yml`에 넣은 변환기 받기·동봉 단계는 한 번도 실행되지 않았다.

## 못 해 본 것

- 인터넷이 없는 PC, 한컴 글꼴이 설치된 PC의 품질, 암호 문서 실제 변환, 이 PC 밖의 Windows 버전.
- macOS·Linux에서의 실제 변환과 대체 글꼴 이름(`Apple SD Gothic Neo`, `Noto Serif CJK KR` 등은 추정).
- 설치 파일(Inno Setup)에 변환기가 들어가는 것. 취소·경과 시간 표시(없음).
- PDF에 들어가는 OS 글꼴 일부의 임베딩 허용 여부.

## 별도 도구로 만들 때 생각해 볼 것

- HWP만이면 앱이 얇아서 변환기 동봉(약 46MB)의 부담이 줄고, 긴 변환(분 단위)에 맞춘 진행 표시·취소를 화면의 중심에 둘 수 있다.
- DOCX/XLSX/PPTX는 별개 문제다: 순수 Dart로는 품질이 안 나오고, 설치된 MS Office(Windows COM, macOS AppleScript)나 LibreOffice(`soffice --headless --convert-to pdf`)를 찾아 쓰고 없으면 안내하는 방식을 검토했다. 구현하지 않았다.
- 한글 → PDF 품질 확인용 시료는 rhwp 저장소의 `samples/`(MIT)가 쓸 만하다. 개인 문서는 시험 자료로 저장소에 넣지 말 것.
