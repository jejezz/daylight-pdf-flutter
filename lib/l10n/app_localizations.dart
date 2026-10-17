import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @aboutTooltip.
  ///
  /// In ko, this message translates to:
  /// **'정보'**
  String get aboutTooltip;

  /// No description provided for @aboutVersion.
  ///
  /// In ko, this message translates to:
  /// **'버전 {version} (빌드 {build})'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutOpenSourceLicenses.
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get aboutOpenSourceLicenses;

  /// No description provided for @aboutRepository.
  ///
  /// In ko, this message translates to:
  /// **'GitHub'**
  String get aboutRepository;

  /// No description provided for @commonClose.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get commonClose;

  /// No description provided for @aboutMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 정보'**
  String aboutMenuItem(String appName);

  /// No description provided for @themeMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'테마'**
  String get themeMenuTooltip;

  /// No description provided for @themeSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정 따르기'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get themeDark;

  /// No description provided for @languageMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get languageMenuTooltip;

  /// No description provided for @languageSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정 따르기 / System'**
  String get languageSystem;

  /// No description provided for @languageSystemShort.
  ///
  /// In ko, this message translates to:
  /// **'시스템'**
  String get languageSystemShort;

  /// No description provided for @aboutTagline.
  ///
  /// In ko, this message translates to:
  /// **'PDF 변환, 보기, 주석, 페이지 조작을 한곳에서'**
  String get aboutTagline;

  /// No description provided for @aboutDescription.
  ///
  /// In ko, this message translates to:
  /// **'이미지·SVG·PDF 호환 .ai 파일을 PDF로 변환하고, PDF를 보고 주석과 메모를 달고, 페이지를 합치고 나누고 정리하는 데스크톱 앱입니다.'**
  String get aboutDescription;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In ko, this message translates to:
  /// **'시작하려면 PDF나 변환할 파일을 끌어다 놓으세요'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyAction.
  ///
  /// In ko, this message translates to:
  /// **'파일 열기'**
  String get homeEmptyAction;

  /// No description provided for @updateCheckMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 확인'**
  String get updateCheckMenuItem;

  /// No description provided for @updateChecking.
  ///
  /// In ko, this message translates to:
  /// **'업데이트를 확인하는 중…'**
  String get updateChecking;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In ko, this message translates to:
  /// **'새 버전이 있습니다'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In ko, this message translates to:
  /// **'{appName} {latest} 버전이 나왔습니다. (현재 {current})'**
  String updateAvailableBody(String appName, String current, String latest);

  /// No description provided for @updateReleaseNotes.
  ///
  /// In ko, this message translates to:
  /// **'변경 내용'**
  String get updateReleaseNotes;

  /// No description provided for @updateNow.
  ///
  /// In ko, this message translates to:
  /// **'지금 업데이트'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get updateLater;

  /// No description provided for @updateSkipVersion.
  ///
  /// In ko, this message translates to:
  /// **'이 버전 건너뛰기'**
  String get updateSkipVersion;

  /// No description provided for @updateDownloading.
  ///
  /// In ko, this message translates to:
  /// **'내려받는 중…'**
  String get updateDownloading;

  /// No description provided for @updateVerifying.
  ///
  /// In ko, this message translates to:
  /// **'파일을 확인하는 중…'**
  String get updateVerifying;

  /// No description provided for @updateDownloadProgress.
  ///
  /// In ko, this message translates to:
  /// **'{received} / {total}'**
  String updateDownloadProgress(String received, String total);

  /// No description provided for @updateCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get updateCancel;

  /// No description provided for @updateFailedTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트하지 못했습니다'**
  String get updateFailedTitle;

  /// No description provided for @updateCheckFailedTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트를 확인하지 못했습니다'**
  String get updateCheckFailedTitle;

  /// No description provided for @updateErrorNetwork.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.'**
  String get updateErrorNetwork;

  /// No description provided for @updateErrorChecksum.
  ///
  /// In ko, this message translates to:
  /// **'내려받은 파일이 올바르지 않아 설치하지 않았습니다. 잠시 뒤에 다시 시도해 주세요.'**
  String get updateErrorChecksum;

  /// No description provided for @updateErrorInstall.
  ///
  /// In ko, this message translates to:
  /// **'설치를 시작하지 못했습니다.'**
  String get updateErrorInstall;

  /// No description provided for @updateErrorGeneric.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 서버에서 예상하지 못한 응답을 받았습니다. 잠시 뒤에 다시 시도해 주세요.'**
  String get updateErrorGeneric;

  /// No description provided for @updateUpToDateTitle.
  ///
  /// In ko, this message translates to:
  /// **'최신 버전입니다'**
  String get updateUpToDateTitle;

  /// No description provided for @updateUpToDateBody.
  ///
  /// In ko, this message translates to:
  /// **'{version} 버전을 사용 중입니다.'**
  String updateUpToDateBody(String version);

  /// No description provided for @updateUnavailableTitle.
  ///
  /// In ko, this message translates to:
  /// **'직접 설치해 주세요'**
  String get updateUnavailableTitle;

  /// No description provided for @updateUnavailableBody.
  ///
  /// In ko, this message translates to:
  /// **'{latest} 버전이 있지만 앱에서 자동으로 설치할 수 없습니다. 릴리스 페이지에서 받아 주세요.'**
  String updateUnavailableBody(String latest);

  /// No description provided for @updateOpenReleasePage.
  ///
  /// In ko, this message translates to:
  /// **'릴리스 페이지 열기'**
  String get updateOpenReleasePage;

  /// No description provided for @updateBrowserDownloadTitle.
  ///
  /// In ko, this message translates to:
  /// **'브라우저에서 내려받습니다'**
  String get updateBrowserDownloadTitle;

  /// No description provided for @updateBrowserDownloadBody.
  ///
  /// In ko, this message translates to:
  /// **'브라우저가 새 버전 내려받기를 시작합니다. 받은 DMG를 열어 {appName} 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.'**
  String updateBrowserDownloadBody(String appName);

  /// No description provided for @updateMacosOpenedTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치 창이 열렸습니다'**
  String get updateMacosOpenedTitle;

  /// No description provided for @updateMacosOpenedBody.
  ///
  /// In ko, this message translates to:
  /// **'열린 창에서 {appName} 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.'**
  String updateMacosOpenedBody(String appName);

  /// No description provided for @updateWindowsInstallTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치 프로그램을 열었습니다'**
  String get updateWindowsInstallTitle;

  /// No description provided for @updateWindowsInstallBody.
  ///
  /// In ko, this message translates to:
  /// **'설치하려면 {appName} 을(를) 종료해야 합니다. 설치 프로그램의 안내를 따라 주세요.'**
  String updateWindowsInstallBody(String appName);

  /// No description provided for @updateQuitApp.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 종료'**
  String updateQuitApp(String appName);

  /// No description provided for @updateLinuxInstallTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치를 준비했습니다'**
  String get updateLinuxInstallTitle;

  /// No description provided for @updateLinuxInstallBody.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 을(를) 종료하고 설치합니다. 설치가 끝나면 자동으로 다시 시작됩니다.'**
  String updateLinuxInstallBody(String appName);

  /// No description provided for @updateQuitAndInstall.
  ///
  /// In ko, this message translates to:
  /// **'종료하고 설치'**
  String get updateQuitAndInstall;

  /// No description provided for @updateBusyTitle.
  ///
  /// In ko, this message translates to:
  /// **'지금은 업데이트할 수 없습니다'**
  String get updateBusyTitle;

  /// No description provided for @updateBusyBody.
  ///
  /// In ko, this message translates to:
  /// **'작업이 진행 중입니다. 끝난 뒤에 다시 시도해 주세요.'**
  String get updateBusyBody;

  /// No description provided for @fileTypePdf.
  ///
  /// In ko, this message translates to:
  /// **'PDF 문서'**
  String get fileTypePdf;

  /// No description provided for @openFailed.
  ///
  /// In ko, this message translates to:
  /// **'파일을 열 수 없어요.'**
  String get openFailed;

  /// No description provided for @viewerZoomIn.
  ///
  /// In ko, this message translates to:
  /// **'확대'**
  String get viewerZoomIn;

  /// No description provided for @viewerZoomOut.
  ///
  /// In ko, this message translates to:
  /// **'축소'**
  String get viewerZoomOut;

  /// No description provided for @viewerThumbnails.
  ///
  /// In ko, this message translates to:
  /// **'썸네일'**
  String get viewerThumbnails;

  /// No description provided for @viewerPageOf.
  ///
  /// In ko, this message translates to:
  /// **'{page} / {total}'**
  String viewerPageOf(int page, int total);

  /// No description provided for @convertTitle.
  ///
  /// In ko, this message translates to:
  /// **'변환'**
  String get convertTitle;

  /// No description provided for @convertAddFiles.
  ///
  /// In ko, this message translates to:
  /// **'파일 추가'**
  String get convertAddFiles;

  /// No description provided for @convertClearFinished.
  ///
  /// In ko, this message translates to:
  /// **'완료 항목 지우기'**
  String get convertClearFinished;

  /// No description provided for @convertFileTypes.
  ///
  /// In ko, this message translates to:
  /// **'이미지, SVG, AI, PDF'**
  String get convertFileTypes;

  /// No description provided for @convertMergeImages.
  ///
  /// In ko, this message translates to:
  /// **'이미지를 한 PDF로 합치기'**
  String get convertMergeImages;

  /// No description provided for @convertOutputSame.
  ///
  /// In ko, this message translates to:
  /// **'원본과 같은 폴더'**
  String get convertOutputSame;

  /// No description provided for @convertEmpty.
  ///
  /// In ko, this message translates to:
  /// **'변환할 이미지나 PDF를 끌어다 놓으세요'**
  String get convertEmpty;

  /// No description provided for @convertDpi.
  ///
  /// In ko, this message translates to:
  /// **'{dpi} DPI'**
  String convertDpi(int dpi);

  /// No description provided for @convertFilesCreated.
  ///
  /// In ko, this message translates to:
  /// **'파일 {count}개를 만들었어요'**
  String convertFilesCreated(int count);

  /// No description provided for @convertSkipped.
  ///
  /// In ko, this message translates to:
  /// **'지원하지 않는 형식 {count}개를 건너뛰었어요: {names}'**
  String convertSkipped(int count, String names);

  /// No description provided for @errUnsupportedFormat.
  ///
  /// In ko, this message translates to:
  /// **'지원하지 않는 형식이에요: {name}'**
  String errUnsupportedFormat(String name);

  /// No description provided for @errCannotRead.
  ///
  /// In ko, this message translates to:
  /// **'파일을 읽을 수 없어요: {name}'**
  String errCannotRead(String name);

  /// No description provided for @errPasswordProtected.
  ///
  /// In ko, this message translates to:
  /// **'암호가 걸린 PDF는 변환할 수 없어요: {name}'**
  String errPasswordProtected(String name);

  /// No description provided for @errWriteFailed.
  ///
  /// In ko, this message translates to:
  /// **'결과를 저장할 수 없어요: {name}'**
  String errWriteFailed(String name);

  /// No description provided for @homeConvertAction.
  ///
  /// In ko, this message translates to:
  /// **'변환'**
  String get homeConvertAction;

  /// No description provided for @errNotPdfCompatible.
  ///
  /// In ko, this message translates to:
  /// **'PDF 호환 파일로 저장되지 않은 .ai예요. Illustrator에서 \"PDF 호환 파일 만들기\"를 켜고 다시 저장해 주세요: {name}'**
  String errNotPdfCompatible(String name);

  /// No description provided for @pagesTitle.
  ///
  /// In ko, this message translates to:
  /// **'페이지 도구'**
  String get pagesTitle;

  /// No description provided for @pagesTabEdit.
  ///
  /// In ko, this message translates to:
  /// **'편집'**
  String get pagesTabEdit;

  /// No description provided for @pagesTabMerge.
  ///
  /// In ko, this message translates to:
  /// **'합치기'**
  String get pagesTabMerge;

  /// No description provided for @pagesTabSplit.
  ///
  /// In ko, this message translates to:
  /// **'나누기'**
  String get pagesTabSplit;

  /// No description provided for @pagesOpenPdf.
  ///
  /// In ko, this message translates to:
  /// **'PDF 열기'**
  String get pagesOpenPdf;

  /// No description provided for @pagesEmpty.
  ///
  /// In ko, this message translates to:
  /// **'편집할 PDF를 열거나 끌어다 놓으세요'**
  String get pagesEmpty;

  /// No description provided for @pagesRotateLeft.
  ///
  /// In ko, this message translates to:
  /// **'왼쪽으로 회전'**
  String get pagesRotateLeft;

  /// No description provided for @pagesRotateRight.
  ///
  /// In ko, this message translates to:
  /// **'오른쪽으로 회전'**
  String get pagesRotateRight;

  /// No description provided for @pagesDelete.
  ///
  /// In ko, this message translates to:
  /// **'선택한 쪽 삭제'**
  String get pagesDelete;

  /// No description provided for @pagesExtract.
  ///
  /// In ko, this message translates to:
  /// **'선택한 쪽만 저장'**
  String get pagesExtract;

  /// No description provided for @pagesSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get pagesSave;

  /// No description provided for @pagesSelectAll.
  ///
  /// In ko, this message translates to:
  /// **'모두 선택'**
  String get pagesSelectAll;

  /// No description provided for @pagesPageLabel.
  ///
  /// In ko, this message translates to:
  /// **'{n}쪽'**
  String pagesPageLabel(int n);

  /// No description provided for @pagesSelectedCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}쪽 선택'**
  String pagesSelectedCount(int count);

  /// No description provided for @pagesNothingSelected.
  ///
  /// In ko, this message translates to:
  /// **'먼저 쪽을 선택하세요'**
  String get pagesNothingSelected;

  /// No description provided for @pagesNoneLeft.
  ///
  /// In ko, this message translates to:
  /// **'남은 쪽이 없어서 저장할 수 없어요'**
  String get pagesNoneLeft;

  /// No description provided for @pagesSaved.
  ///
  /// In ko, this message translates to:
  /// **'저장했어요: {name}'**
  String pagesSaved(String name);

  /// No description provided for @pagesSavedMany.
  ///
  /// In ko, this message translates to:
  /// **'파일 {count}개를 만들었어요'**
  String pagesSavedMany(int count);

  /// No description provided for @pagesReset.
  ///
  /// In ko, this message translates to:
  /// **'되돌리기'**
  String get pagesReset;

  /// No description provided for @mergeAdd.
  ///
  /// In ko, this message translates to:
  /// **'PDF 추가'**
  String get mergeAdd;

  /// No description provided for @mergeAction.
  ///
  /// In ko, this message translates to:
  /// **'합쳐서 저장'**
  String get mergeAction;

  /// No description provided for @mergeNeedTwo.
  ///
  /// In ko, this message translates to:
  /// **'PDF를 2개 이상 추가하세요'**
  String get mergeNeedTwo;

  /// No description provided for @mergeRemove.
  ///
  /// In ko, this message translates to:
  /// **'목록에서 빼기'**
  String get mergeRemove;

  /// No description provided for @mergeEmpty.
  ///
  /// In ko, this message translates to:
  /// **'합칠 PDF를 추가하세요'**
  String get mergeEmpty;

  /// No description provided for @splitChoose.
  ///
  /// In ko, this message translates to:
  /// **'나눌 PDF 선택'**
  String get splitChoose;

  /// No description provided for @splitModeEach.
  ///
  /// In ko, this message translates to:
  /// **'한 쪽씩'**
  String get splitModeEach;

  /// No description provided for @splitModeEveryN.
  ///
  /// In ko, this message translates to:
  /// **'N쪽마다'**
  String get splitModeEveryN;

  /// No description provided for @splitModeRanges.
  ///
  /// In ko, this message translates to:
  /// **'범위로'**
  String get splitModeRanges;

  /// No description provided for @splitEveryNLabel.
  ///
  /// In ko, this message translates to:
  /// **'쪽 수'**
  String get splitEveryNLabel;

  /// No description provided for @splitRangesLabel.
  ///
  /// In ko, this message translates to:
  /// **'범위 (예: 1-3, 5, 8-)'**
  String get splitRangesLabel;

  /// No description provided for @splitAction.
  ///
  /// In ko, this message translates to:
  /// **'나누기'**
  String get splitAction;

  /// No description provided for @splitPageCount.
  ///
  /// In ko, this message translates to:
  /// **'전체 {count}쪽'**
  String splitPageCount(int count);

  /// No description provided for @splitChooseFolder.
  ///
  /// In ko, this message translates to:
  /// **'저장할 폴더 선택'**
  String get splitChooseFolder;

  /// No description provided for @errInvalidRange.
  ///
  /// In ko, this message translates to:
  /// **'쪽 범위를 이해할 수 없어요: {name}'**
  String errInvalidRange(String name);

  /// No description provided for @viewerEditPages.
  ///
  /// In ko, this message translates to:
  /// **'페이지 편집'**
  String get viewerEditPages;

  /// No description provided for @homePagesAction.
  ///
  /// In ko, this message translates to:
  /// **'페이지 도구'**
  String get homePagesAction;

  /// No description provided for @annotHighlight.
  ///
  /// In ko, this message translates to:
  /// **'형광펜 (선택한 글자)'**
  String get annotHighlight;

  /// No description provided for @annotUnderline.
  ///
  /// In ko, this message translates to:
  /// **'밑줄 (선택한 글자)'**
  String get annotUnderline;

  /// No description provided for @annotNote.
  ///
  /// In ko, this message translates to:
  /// **'메모 (쪽을 클릭)'**
  String get annotNote;

  /// No description provided for @annotInk.
  ///
  /// In ko, this message translates to:
  /// **'손글씨'**
  String get annotInk;

  /// No description provided for @annotRectangle.
  ///
  /// In ko, this message translates to:
  /// **'사각형'**
  String get annotRectangle;

  /// No description provided for @annotCircle.
  ///
  /// In ko, this message translates to:
  /// **'원'**
  String get annotCircle;

  /// No description provided for @annotColor.
  ///
  /// In ko, this message translates to:
  /// **'색'**
  String get annotColor;

  /// No description provided for @annotList.
  ///
  /// In ko, this message translates to:
  /// **'주석 목록'**
  String get annotList;

  /// No description provided for @annotSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get annotSave;

  /// No description provided for @annotSelectTextFirst.
  ///
  /// In ko, this message translates to:
  /// **'먼저 글자를 선택하세요'**
  String get annotSelectTextFirst;

  /// No description provided for @annotNoteTitle.
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get annotNoteTitle;

  /// No description provided for @annotNoteHint.
  ///
  /// In ko, this message translates to:
  /// **'메모 내용'**
  String get annotNoteHint;

  /// No description provided for @annotNoteAdd.
  ///
  /// In ko, this message translates to:
  /// **'추가'**
  String get annotNoteAdd;

  /// No description provided for @commonCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get commonCancel;

  /// No description provided for @annotEmpty.
  ///
  /// In ko, this message translates to:
  /// **'주석이 없어요'**
  String get annotEmpty;

  /// No description provided for @annotTypeHighlight.
  ///
  /// In ko, this message translates to:
  /// **'형광펜'**
  String get annotTypeHighlight;

  /// No description provided for @annotTypeUnderline.
  ///
  /// In ko, this message translates to:
  /// **'밑줄'**
  String get annotTypeUnderline;

  /// No description provided for @annotTypeNote.
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get annotTypeNote;

  /// No description provided for @annotTypeInk.
  ///
  /// In ko, this message translates to:
  /// **'손글씨'**
  String get annotTypeInk;

  /// No description provided for @annotTypeRectangle.
  ///
  /// In ko, this message translates to:
  /// **'사각형'**
  String get annotTypeRectangle;

  /// No description provided for @annotTypeCircle.
  ///
  /// In ko, this message translates to:
  /// **'원'**
  String get annotTypeCircle;

  /// No description provided for @annotTypeOther.
  ///
  /// In ko, this message translates to:
  /// **'주석'**
  String get annotTypeOther;

  /// No description provided for @annotDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get annotDelete;

  /// No description provided for @annotUnsavedTitle.
  ///
  /// In ko, this message translates to:
  /// **'저장하지 않은 주석이 있어요'**
  String get annotUnsavedTitle;

  /// No description provided for @annotUnsavedBody.
  ///
  /// In ko, this message translates to:
  /// **'저장하지 않고 나가면 이번에 단 주석이 사라져요.'**
  String get annotUnsavedBody;

  /// No description provided for @annotDiscard.
  ///
  /// In ko, this message translates to:
  /// **'저장 안 함'**
  String get annotDiscard;

  /// No description provided for @annotFailed.
  ///
  /// In ko, this message translates to:
  /// **'주석을 처리하지 못했어요.'**
  String get annotFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
