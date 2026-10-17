// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutTooltip => 'About';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get aboutOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get aboutRepository => 'GitHub';

  @override
  String get commonClose => 'Close';

  @override
  String aboutMenuItem(String appName) {
    return 'About $appName';
  }

  @override
  String get themeMenuTooltip => 'Theme';

  @override
  String get themeSystem => 'Follow System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageMenuTooltip => 'Language';

  @override
  String get languageSystem => 'System / 시스템 설정 따르기';

  @override
  String get languageSystemShort => 'System';

  @override
  String get aboutTagline =>
      'Convert, view, annotate and organize PDFs in one place';

  @override
  String get aboutDescription =>
      'A desktop app that converts images, SVG and PDF-compatible .ai files to PDF, lets you view PDFs, add annotations and notes, and merge, split and reorder pages.';

  @override
  String get homeEmptyTitle => 'Drop a PDF or a file to convert to get started';

  @override
  String get homeEmptyAction => 'Open file';

  @override
  String get updateCheckMenuItem => 'Check for Updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateAvailableTitle => 'A new version is available';

  @override
  String updateAvailableBody(String appName, String current, String latest) {
    return '$appName $latest is available. You have $current.';
  }

  @override
  String get updateReleaseNotes => 'What\'s new';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateLater => 'Later';

  @override
  String get updateSkipVersion => 'Skip this version';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String get updateVerifying => 'Verifying the file…';

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateCancel => 'Cancel';

  @override
  String get updateFailedTitle => 'Couldn\'t update';

  @override
  String get updateCheckFailedTitle => 'Couldn\'t check for updates';

  @override
  String get updateErrorNetwork =>
      'Couldn\'t reach the update server. Check your internet connection and try again.';

  @override
  String get updateErrorChecksum =>
      'The downloaded file didn\'t pass verification, so it was not installed. Please try again later.';

  @override
  String get updateErrorInstall => 'Couldn\'t start the installation.';

  @override
  String get updateErrorGeneric =>
      'The update server sent an unexpected response. Please try again later.';

  @override
  String get updateUpToDateTitle => 'You\'re up to date';

  @override
  String updateUpToDateBody(String version) {
    return 'You\'re using version $version.';
  }

  @override
  String get updateUnavailableTitle => 'Install it manually';

  @override
  String updateUnavailableBody(String latest) {
    return 'Version $latest is available, but the app can\'t install it automatically. Please download it from the release page.';
  }

  @override
  String get updateOpenReleasePage => 'Open release page';

  @override
  String get updateBrowserDownloadTitle => 'Downloading in your browser';

  @override
  String updateBrowserDownloadBody(String appName) {
    return 'Your browser is downloading the new version. Open the DMG and drag $appName to the Applications folder. If it\'s running, quit it first and replace the old copy.';
  }

  @override
  String get updateMacosOpenedTitle => 'The installer window is open';

  @override
  String updateMacosOpenedBody(String appName) {
    return 'In the window that opened, drag $appName to the Applications folder. If it\'s running, quit it first and replace the old copy.';
  }

  @override
  String get updateWindowsInstallTitle => 'The installer is open';

  @override
  String updateWindowsInstallBody(String appName) {
    return '$appName must quit before it can be updated. Follow the installer\'s instructions.';
  }

  @override
  String updateQuitApp(String appName) {
    return 'Quit $appName';
  }

  @override
  String get updateLinuxInstallTitle => 'Ready to install';

  @override
  String updateLinuxInstallBody(String appName) {
    return '$appName will quit and install the update, then start again automatically.';
  }

  @override
  String get updateQuitAndInstall => 'Quit and install';

  @override
  String get updateBusyTitle => 'Can\'t update right now';

  @override
  String get updateBusyBody =>
      'A task is in progress. Please try again when it has finished.';

  @override
  String get fileTypePdf => 'PDF document';

  @override
  String get openFailed => 'Couldn\'t open the file.';

  @override
  String get viewerZoomIn => 'Zoom in';

  @override
  String get viewerZoomOut => 'Zoom out';

  @override
  String get viewerThumbnails => 'Thumbnails';

  @override
  String viewerPageOf(int page, int total) {
    return '$page / $total';
  }

  @override
  String get convertTitle => 'Convert';

  @override
  String get convertAddFiles => 'Add files';

  @override
  String get convertClearFinished => 'Clear finished';

  @override
  String get convertFileTypes => 'Images, SVG, AI, PDF';

  @override
  String get convertMergeImages => 'Merge images into one PDF';

  @override
  String get convertOutputSame => 'Same folder as source';

  @override
  String get convertEmpty => 'Drop images or PDFs to convert';

  @override
  String convertDpi(int dpi) {
    return '$dpi DPI';
  }

  @override
  String convertFilesCreated(int count) {
    return 'Created $count files';
  }

  @override
  String convertSkipped(int count, String names) {
    return 'Skipped $count unsupported files: $names';
  }

  @override
  String errUnsupportedFormat(String name) {
    return 'Unsupported format: $name';
  }

  @override
  String errCannotRead(String name) {
    return 'Couldn\'t read the file: $name';
  }

  @override
  String errPasswordProtected(String name) {
    return 'Password-protected PDFs can\'t be converted: $name';
  }

  @override
  String errWriteFailed(String name) {
    return 'Couldn\'t save the result: $name';
  }

  @override
  String get homeConvertAction => 'Convert';

  @override
  String errNotPdfCompatible(String name) {
    return 'This .ai was saved without PDF compatibility. In Illustrator, turn on \"Create PDF Compatible File\" and save again: $name';
  }

  @override
  String get pagesTitle => 'Page tools';

  @override
  String get pagesTabEdit => 'Edit';

  @override
  String get pagesTabMerge => 'Merge';

  @override
  String get pagesTabSplit => 'Split';

  @override
  String get pagesOpenPdf => 'Open PDF';

  @override
  String get pagesEmpty => 'Open or drop a PDF to edit';

  @override
  String get pagesRotateLeft => 'Rotate left';

  @override
  String get pagesRotateRight => 'Rotate right';

  @override
  String get pagesDelete => 'Delete selected pages';

  @override
  String get pagesExtract => 'Save selected pages only';

  @override
  String get pagesSave => 'Save';

  @override
  String get pagesSelectAll => 'Select all';

  @override
  String pagesPageLabel(int n) {
    return 'Page $n';
  }

  @override
  String pagesSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get pagesNothingSelected => 'Select pages first';

  @override
  String get pagesNoneLeft => 'No pages left to save';

  @override
  String pagesSaved(String name) {
    return 'Saved: $name';
  }

  @override
  String pagesSavedMany(int count) {
    return 'Created $count files';
  }

  @override
  String get pagesReset => 'Reset';

  @override
  String get mergeAdd => 'Add PDFs';

  @override
  String get mergeAction => 'Merge and save';

  @override
  String get mergeNeedTwo => 'Add at least 2 PDFs';

  @override
  String get mergeRemove => 'Remove from list';

  @override
  String get mergeEmpty => 'Add PDFs to merge';

  @override
  String get splitChoose => 'Choose a PDF to split';

  @override
  String get splitModeEach => 'One page each';

  @override
  String get splitModeEveryN => 'Every N pages';

  @override
  String get splitModeRanges => 'By ranges';

  @override
  String get splitEveryNLabel => 'Pages';

  @override
  String get splitRangesLabel => 'Ranges (e.g. 1-3, 5, 8-)';

  @override
  String get splitAction => 'Split';

  @override
  String splitPageCount(int count) {
    return '$count pages in total';
  }

  @override
  String get splitChooseFolder => 'Choose output folder';

  @override
  String errInvalidRange(String name) {
    return 'Couldn\'t understand the page range: $name';
  }

  @override
  String get viewerEditPages => 'Edit pages';

  @override
  String get homePagesAction => 'Page tools';
}
