// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get aboutTooltip => '정보';

  @override
  String aboutVersion(String version, String build) {
    return '버전 $version (빌드 $build)';
  }

  @override
  String get aboutOpenSourceLicenses => '오픈소스 라이선스';

  @override
  String get aboutRepository => 'GitHub';

  @override
  String get commonClose => '닫기';

  @override
  String aboutMenuItem(String appName) {
    return '$appName 정보';
  }

  @override
  String get themeMenuTooltip => '테마';

  @override
  String get themeSystem => '시스템 설정 따르기';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get languageMenuTooltip => '언어';

  @override
  String get languageSystem => '시스템 설정 따르기 / System';

  @override
  String get languageSystemShort => '시스템';

  @override
  String get aboutTagline => 'PDF 변환, 보기, 주석, 페이지 조작을 한곳에서';

  @override
  String get aboutDescription =>
      '이미지·SVG·PDF 호환 .ai 파일을 PDF로 변환하고, PDF를 보고 주석과 메모를 달고, 페이지를 합치고 나누고 정리하는 데스크톱 앱입니다.';

  @override
  String get homeEmptyTitle => '시작하려면 PDF나 변환할 파일을 끌어다 놓으세요';

  @override
  String get homeEmptyAction => '파일 열기';

  @override
  String get updateCheckMenuItem => '업데이트 확인';

  @override
  String get updateChecking => '업데이트를 확인하는 중…';

  @override
  String get updateAvailableTitle => '새 버전이 있습니다';

  @override
  String updateAvailableBody(String appName, String current, String latest) {
    return '$appName $latest 버전이 나왔습니다. (현재 $current)';
  }

  @override
  String get updateReleaseNotes => '변경 내용';

  @override
  String get updateNow => '지금 업데이트';

  @override
  String get updateLater => '나중에';

  @override
  String get updateSkipVersion => '이 버전 건너뛰기';

  @override
  String get updateDownloading => '내려받는 중…';

  @override
  String get updateVerifying => '파일을 확인하는 중…';

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateCancel => '취소';

  @override
  String get updateFailedTitle => '업데이트하지 못했습니다';

  @override
  String get updateCheckFailedTitle => '업데이트를 확인하지 못했습니다';

  @override
  String get updateErrorNetwork =>
      '업데이트 서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';

  @override
  String get updateErrorChecksum =>
      '내려받은 파일이 올바르지 않아 설치하지 않았습니다. 잠시 뒤에 다시 시도해 주세요.';

  @override
  String get updateErrorInstall => '설치를 시작하지 못했습니다.';

  @override
  String get updateErrorGeneric =>
      '업데이트 서버에서 예상하지 못한 응답을 받았습니다. 잠시 뒤에 다시 시도해 주세요.';

  @override
  String get updateUpToDateTitle => '최신 버전입니다';

  @override
  String updateUpToDateBody(String version) {
    return '$version 버전을 사용 중입니다.';
  }

  @override
  String get updateUnavailableTitle => '직접 설치해 주세요';

  @override
  String updateUnavailableBody(String latest) {
    return '$latest 버전이 있지만 앱에서 자동으로 설치할 수 없습니다. 릴리스 페이지에서 받아 주세요.';
  }

  @override
  String get updateOpenReleasePage => '릴리스 페이지 열기';

  @override
  String get updateBrowserDownloadTitle => '브라우저에서 내려받습니다';

  @override
  String updateBrowserDownloadBody(String appName) {
    return '브라우저가 새 버전 내려받기를 시작합니다. 받은 DMG를 열어 $appName 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.';
  }

  @override
  String get updateMacosOpenedTitle => '설치 창이 열렸습니다';

  @override
  String updateMacosOpenedBody(String appName) {
    return '열린 창에서 $appName 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.';
  }

  @override
  String get updateWindowsInstallTitle => '설치 프로그램을 열었습니다';

  @override
  String updateWindowsInstallBody(String appName) {
    return '설치하려면 $appName 을(를) 종료해야 합니다. 설치 프로그램의 안내를 따라 주세요.';
  }

  @override
  String updateQuitApp(String appName) {
    return '$appName 종료';
  }

  @override
  String get updateLinuxInstallTitle => '설치를 준비했습니다';

  @override
  String updateLinuxInstallBody(String appName) {
    return '$appName 을(를) 종료하고 설치합니다. 설치가 끝나면 자동으로 다시 시작됩니다.';
  }

  @override
  String get updateQuitAndInstall => '종료하고 설치';

  @override
  String get updateBusyTitle => '지금은 업데이트할 수 없습니다';

  @override
  String get updateBusyBody => '작업이 진행 중입니다. 끝난 뒤에 다시 시도해 주세요.';

  @override
  String get fileTypePdf => 'PDF 문서';

  @override
  String get openFailed => '파일을 열 수 없어요.';

  @override
  String get viewerZoomIn => '확대';

  @override
  String get viewerZoomOut => '축소';

  @override
  String get viewerThumbnails => '썸네일';

  @override
  String viewerPageOf(int page, int total) {
    return '$page / $total';
  }

  @override
  String get convertTitle => '변환';

  @override
  String get convertAddFiles => '파일 추가';

  @override
  String get convertClearFinished => '완료 항목 지우기';

  @override
  String get convertFileTypes => '이미지, SVG, AI, PDF';

  @override
  String get convertMergeImages => '이미지를 한 PDF로 합치기';

  @override
  String get convertOutputSame => '원본과 같은 폴더';

  @override
  String get convertEmpty => '변환할 이미지나 PDF를 끌어다 놓으세요';

  @override
  String convertDpi(int dpi) {
    return '$dpi DPI';
  }

  @override
  String convertFilesCreated(int count) {
    return '파일 $count개를 만들었어요';
  }

  @override
  String convertSkipped(int count, String names) {
    return '지원하지 않는 형식 $count개를 건너뛰었어요: $names';
  }

  @override
  String errUnsupportedFormat(String name) {
    return '지원하지 않는 형식이에요: $name';
  }

  @override
  String errCannotRead(String name) {
    return '파일을 읽을 수 없어요: $name';
  }

  @override
  String errPasswordProtected(String name) {
    return '암호가 걸린 PDF는 변환할 수 없어요: $name';
  }

  @override
  String errWriteFailed(String name) {
    return '결과를 저장할 수 없어요: $name';
  }

  @override
  String get homeConvertAction => '변환';

  @override
  String errNotPdfCompatible(String name) {
    return 'PDF 호환 파일로 저장되지 않은 .ai예요. Illustrator에서 \"PDF 호환 파일 만들기\"를 켜고 다시 저장해 주세요: $name';
  }

  @override
  String get pagesTitle => '페이지 도구';

  @override
  String get pagesTabEdit => '편집';

  @override
  String get pagesTabMerge => '합치기';

  @override
  String get pagesTabSplit => '나누기';

  @override
  String get pagesOpenPdf => 'PDF 열기';

  @override
  String get pagesEmpty => '편집할 PDF를 열거나 끌어다 놓으세요';

  @override
  String get pagesRotateLeft => '왼쪽으로 회전';

  @override
  String get pagesRotateRight => '오른쪽으로 회전';

  @override
  String get pagesDelete => '선택한 쪽 삭제';

  @override
  String get pagesExtract => '선택한 쪽만 저장';

  @override
  String get pagesSave => '저장';

  @override
  String get pagesSelectAll => '모두 선택';

  @override
  String pagesPageLabel(int n) {
    return '$n쪽';
  }

  @override
  String pagesSelectedCount(int count) {
    return '$count쪽 선택';
  }

  @override
  String get pagesNothingSelected => '먼저 쪽을 선택하세요';

  @override
  String get pagesNoneLeft => '남은 쪽이 없어서 저장할 수 없어요';

  @override
  String pagesSaved(String name) {
    return '저장했어요: $name';
  }

  @override
  String pagesSavedMany(int count) {
    return '파일 $count개를 만들었어요';
  }

  @override
  String get pagesReset => '되돌리기';

  @override
  String get mergeAdd => 'PDF 추가';

  @override
  String get mergeAction => '합쳐서 저장';

  @override
  String get mergeNeedTwo => 'PDF를 2개 이상 추가하세요';

  @override
  String get mergeRemove => '목록에서 빼기';

  @override
  String get mergeEmpty => '합칠 PDF를 추가하세요';

  @override
  String get splitChoose => '나눌 PDF 선택';

  @override
  String get splitModeEach => '한 쪽씩';

  @override
  String get splitModeEveryN => 'N쪽마다';

  @override
  String get splitModeRanges => '범위로';

  @override
  String get splitEveryNLabel => '쪽 수';

  @override
  String get splitRangesLabel => '범위 (예: 1-3, 5, 8-)';

  @override
  String get splitAction => '나누기';

  @override
  String splitPageCount(int count) {
    return '전체 $count쪽';
  }

  @override
  String get splitChooseFolder => '저장할 폴더 선택';

  @override
  String errInvalidRange(String name) {
    return '쪽 범위를 이해할 수 없어요: $name';
  }

  @override
  String get viewerEditPages => '페이지 편집';

  @override
  String get homePagesAction => '페이지 도구';

  @override
  String get annotHighlight => '형광펜 (선택한 글자)';

  @override
  String get annotUnderline => '밑줄 (선택한 글자)';

  @override
  String get annotNote => '메모 (쪽을 클릭)';

  @override
  String get annotInk => '손글씨';

  @override
  String get annotRectangle => '사각형';

  @override
  String get annotCircle => '원';

  @override
  String get annotColor => '색';

  @override
  String get annotList => '주석 목록';

  @override
  String get annotSave => '저장';

  @override
  String get annotSelectTextFirst => '먼저 글자를 선택하세요';

  @override
  String get annotNoteTitle => '메모';

  @override
  String get annotNoteHint => '메모 내용';

  @override
  String get annotNoteAdd => '추가';

  @override
  String get commonCancel => '취소';

  @override
  String get annotEmpty => '주석이 없어요';

  @override
  String get annotTypeHighlight => '형광펜';

  @override
  String get annotTypeUnderline => '밑줄';

  @override
  String get annotTypeNote => '메모';

  @override
  String get annotTypeInk => '손글씨';

  @override
  String get annotTypeRectangle => '사각형';

  @override
  String get annotTypeCircle => '원';

  @override
  String get annotTypeOther => '주석';

  @override
  String get annotDelete => '삭제';

  @override
  String get annotUnsavedTitle => '저장하지 않은 주석이 있어요';

  @override
  String get annotUnsavedBody => '저장하지 않고 나가면 이번에 단 주석이 사라져요.';

  @override
  String get annotDiscard => '저장 안 함';

  @override
  String get annotFailed => '주석을 처리하지 못했어요.';

  @override
  String get homeConvertHint => '이미지·SVG·AI를 PDF로, PDF를 이미지로';

  @override
  String get homePagesHint => '합치기, 나누기, 회전, 삭제, 순서 바꾸기';

  @override
  String get homeDropSubtitle => 'PDF는 바로 열고, 이미지·SVG·AI는 변환으로 보내요';

  @override
  String annotListLabel(int count) {
    return '주석 $count';
  }

  @override
  String get annotUnsavedShort => '저장 안 됨';

  @override
  String get annotHintNote => '쪽을 클릭해 메모를 놓으세요';

  @override
  String get annotHintInk => '쪽 위에서 끌어 그리세요';

  @override
  String get annotHintShape => '끌어서 영역을 지정하세요';

  @override
  String get annotListTitle => '주석';

  @override
  String get viewerGoToPage => '쪽 이동';

  @override
  String get mergeDropHint => '여기에 PDF를 놓으세요';

  @override
  String get splitDropHint => '나눌 PDF를 끌어다 놓거나 선택하세요';

  @override
  String get splitChange => '다른 PDF';

  @override
  String splitPreview(int count) {
    return '파일 $count개로 나뉘어요';
  }

  @override
  String get pagesDropHere => '여기에 놓아서 맨 뒤로 보내기';

  @override
  String get pagesMoveToEnd => '맨 뒤';

  @override
  String get convertStatusPending => '대기';

  @override
  String get convertStatusRunning => '변환 중';

  @override
  String get convertStatusDone => '완료';

  @override
  String get convertStatusFailed => '실패';

  @override
  String get convertReveal => '폴더에서 보기';

  @override
  String get convertOpenResult => '열기';

  @override
  String get convertSectionImages => '이미지 → PDF';

  @override
  String get convertSectionPdf => 'PDF → 이미지';

  @override
  String get convertSectionOutput => '저장 위치';

  @override
  String get convertQueueTitle => '대기열';

  @override
  String get convertFormatLabel => '형식';

  @override
  String get convertResolutionLabel => '해상도';

  @override
  String get convertImagesNote =>
      'PNG, JPG, BMP, GIF, WebP, TIFF · SVG · AI(PDF 호환)';

  @override
  String get annotUndo => '실행 취소';

  @override
  String annotUndoTip(String shortcut) {
    return '실행 취소 ($shortcut)';
  }

  @override
  String get homeRecentTitle => '최근 파일';

  @override
  String get homeRecentClear => '목록 지우기';

  @override
  String get homeRecentRemove => '목록에서 지우기';

  @override
  String get printTitle => '인쇄';

  @override
  String printTip(String shortcut) {
    return '인쇄 ($shortcut)';
  }

  @override
  String get printAction => '인쇄';

  @override
  String get printRange => '인쇄할 쪽';

  @override
  String get printRangeAll => '전체';

  @override
  String get printRangeCurrent => '현재 쪽';

  @override
  String get printRangeCustom => '쪽 지정';

  @override
  String get printRangeHint => '예: 1-3, 5, 8-';

  @override
  String get printParity => '홀수·짝수';

  @override
  String get printParityAll => '모두';

  @override
  String get printParityOdd => '홀수 쪽';

  @override
  String get printParityEven => '짝수 쪽';

  @override
  String get printReverse => '마지막 쪽부터 거꾸로';

  @override
  String get printAnnotations => '주석 포함 (메모·형광펜·그림)';

  @override
  String get printScale => '크기';

  @override
  String get printScaleFit => '용지에 맞춤';

  @override
  String get printScaleShrink => '큰 쪽만 줄임';

  @override
  String get printScaleActual => '원래 크기';

  @override
  String get printMargin => '여백';

  @override
  String get printMarginNone => '없음';

  @override
  String get printPaper => '용지';

  @override
  String get printAutoOrientation => '쪽 방향에 맞춰 용지 돌리기';

  @override
  String printPageCount(int count) {
    return '$count쪽 인쇄';
  }

  @override
  String printPreviewNote(int count) {
    return '미리보기는 처음 $count쪽까지 보여요';
  }

  @override
  String get printPreviewing => '미리보기 만드는 중…';

  @override
  String get printFailed => '인쇄를 준비하지 못했어요';

  @override
  String get printNextStep => '프린터, 매수, 양면, 컬러는 다음에 뜨는 인쇄 창에서 정해요.';

  @override
  String get printContinue => '인쇄 창 열기';

  @override
  String get printPerSheet => '한 장에 모아 찍기';

  @override
  String printPerSheetValue(int n) {
    return '$n쪽';
  }

  @override
  String get printBooklet => '소책자 (접어서 철하기)';

  @override
  String get printBookletHint =>
      '양면 인쇄(짧은 쪽 넘김)로 찍고 반으로 접으세요. 쪽 수는 4의 배수로 빈 쪽이 채워져요.';

  @override
  String get printSheetBorder => '쪽마다 테두리 그리기';

  @override
  String get printNumbers => '쪽 번호';

  @override
  String get printNumbersNone => '없음';

  @override
  String get printNumbersBottomCenter => '아래 가운데';

  @override
  String get printNumbersBottomRight => '아래 오른쪽';

  @override
  String get printNumbersBottomLeft => '아래 왼쪽';

  @override
  String get printNumbersTopRight => '위 오른쪽';

  @override
  String get printNumberTotal => '전체 쪽수와 함께 (3 / 12)';

  @override
  String get printWatermark => '워터마크 글자';

  @override
  String get printWatermarkHint => '예: 사본, 기밀, DRAFT';

  @override
  String get printGrayscale => '흑백으로 확실히 찍기';

  @override
  String get printGrayscaleHint =>
      '쪽을 회색 이미지로 바꿔 찍어서 글자도 이미지가 돼요. 오래 걸리고 파일이 커질 수 있어요.';

  @override
  String viewerSearchTip(String shortcut) {
    return '검색 ($shortcut)';
  }

  @override
  String get searchHint => 'PDF 안에서 찾기';

  @override
  String get searchNoResults => '찾지 못했어요';

  @override
  String searchCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get searchPrev => '이전 결과';

  @override
  String get searchNext => '다음 결과';

  @override
  String get searchClose => '검색 닫기';

  @override
  String get searchSearching => '찾는 중…';

  @override
  String get sidebarPages => '쪽';

  @override
  String get sidebarOutline => '목차';

  @override
  String get viewerFit => '보기 맞춤';

  @override
  String get viewerFitWidth => '너비에 맞춤';

  @override
  String get viewerFitPage => '쪽에 맞춤';

  @override
  String get viewerActualSize => '실제 크기 (100%)';

  @override
  String get passwordTitle => '암호가 필요해요';

  @override
  String passwordBody(String name) {
    return '$name은(는) 암호로 보호되어 있어요.';
  }

  @override
  String get passwordWrong => '암호가 맞지 않아요. 다시 입력해 주세요.';

  @override
  String get passwordHint => '암호';

  @override
  String get passwordShow => '암호 보기';

  @override
  String get passwordHide => '암호 숨기기';

  @override
  String get passwordOpen => '열기';

  @override
  String get viewerCopy => '복사';

  @override
  String get homeMobileOpenTitle => 'PDF 열기';

  @override
  String get homeMobileOpenHint => '이 기기나 클라우드에서 파일을 골라요';

  @override
  String get homeMobileEmptyTitle => 'PDF를 열어 읽고 메모해 보세요';

  @override
  String get homeMobileEmptyHint => '파일 앱이나 다른 앱에서 PDF를 눌러도 이 앱으로 열 수 있어요';

  @override
  String homeRecentMeta(String date, String size) {
    return '$date · $size';
  }
}
