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

  @override
  String get annotHighlight => 'Highlight (selected text)';

  @override
  String get annotUnderline => 'Underline (selected text)';

  @override
  String get annotNote => 'Note (click on the page)';

  @override
  String get annotInk => 'Freehand';

  @override
  String get annotRectangle => 'Rectangle';

  @override
  String get annotCircle => 'Circle';

  @override
  String get annotColor => 'Color';

  @override
  String get annotList => 'Annotation list';

  @override
  String get annotSave => 'Save';

  @override
  String get annotSelectTextFirst => 'Select some text first';

  @override
  String get annotNoteTitle => 'Note';

  @override
  String get annotNoteHint => 'Note text';

  @override
  String get annotNoteAdd => 'Add';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get annotEmpty => 'No annotations';

  @override
  String get annotTypeHighlight => 'Highlight';

  @override
  String get annotTypeUnderline => 'Underline';

  @override
  String get annotTypeNote => 'Note';

  @override
  String get annotTypeInk => 'Freehand';

  @override
  String get annotTypeRectangle => 'Rectangle';

  @override
  String get annotTypeCircle => 'Circle';

  @override
  String get annotTypeOther => 'Annotation';

  @override
  String get annotDelete => 'Delete';

  @override
  String get annotUnsavedTitle => 'You have unsaved annotations';

  @override
  String get annotUnsavedBody =>
      'If you leave without saving, the annotations you added are lost.';

  @override
  String get annotDiscard => 'Discard';

  @override
  String get annotFailed => 'Couldn\'t process the annotation.';

  @override
  String get homeConvertHint => 'Images, SVG and AI to PDF, or PDF to images';

  @override
  String get homePagesHint => 'Merge, split, rotate, delete and reorder pages';

  @override
  String get homeDropSubtitle =>
      'PDFs open right away; images, SVG and AI go to Convert';

  @override
  String annotListLabel(int count) {
    return 'Annotations $count';
  }

  @override
  String get annotUnsavedShort => 'Not saved';

  @override
  String get annotHintNote => 'Click the page to place a note';

  @override
  String get annotHintInk => 'Drag on the page to draw';

  @override
  String get annotHintShape => 'Drag to set the area';

  @override
  String get annotListTitle => 'Annotations';

  @override
  String get viewerGoToPage => 'Go to page';

  @override
  String get mergeDropHint => 'Drop PDFs here';

  @override
  String get splitDropHint => 'Drop a PDF to split, or choose one';

  @override
  String get splitChange => 'Another PDF';

  @override
  String splitPreview(int count) {
    return 'Makes $count files';
  }

  @override
  String get pagesDropHere => 'Drop here to move to the end';

  @override
  String get pagesMoveToEnd => 'End';

  @override
  String get convertStatusPending => 'Waiting';

  @override
  String get convertStatusRunning => 'Converting';

  @override
  String get convertStatusDone => 'Done';

  @override
  String get convertStatusFailed => 'Failed';

  @override
  String get convertReveal => 'Show in folder';

  @override
  String get convertOpenResult => 'Open';

  @override
  String get convertSectionImages => 'Images → PDF';

  @override
  String get convertSectionPdf => 'PDF → images';

  @override
  String get convertSectionOutput => 'Save to';

  @override
  String get convertQueueTitle => 'Queue';

  @override
  String get convertFormatLabel => 'Format';

  @override
  String get convertResolutionLabel => 'Resolution';

  @override
  String get convertImagesNote =>
      'PNG, JPG, BMP, GIF, WebP, TIFF · SVG · AI (PDF-compatible)';

  @override
  String get annotUndo => 'Undo';

  @override
  String annotUndoTip(String shortcut) {
    return 'Undo ($shortcut)';
  }

  @override
  String get homeRecentTitle => 'Recent files';

  @override
  String get homeRecentClear => 'Clear list';

  @override
  String get homeRecentRemove => 'Remove from list';

  @override
  String get printTitle => 'Print';

  @override
  String printTip(String shortcut) {
    return 'Print ($shortcut)';
  }

  @override
  String get printAction => 'Print';

  @override
  String get printRange => 'Pages to print';

  @override
  String get printRangeAll => 'All';

  @override
  String get printRangeCurrent => 'Current page';

  @override
  String get printRangeCustom => 'Pages';

  @override
  String get printRangeHint => 'e.g. 1-3, 5, 8-';

  @override
  String get printParity => 'Odd / even';

  @override
  String get printParityAll => 'All';

  @override
  String get printParityOdd => 'Odd pages';

  @override
  String get printParityEven => 'Even pages';

  @override
  String get printReverse => 'Reverse order (last page first)';

  @override
  String get printAnnotations =>
      'Include annotations (notes, highlights, drawings)';

  @override
  String get printScale => 'Size';

  @override
  String get printScaleFit => 'Fit to paper';

  @override
  String get printScaleShrink => 'Shrink large pages only';

  @override
  String get printScaleActual => 'Actual size';

  @override
  String get printMargin => 'Margin';

  @override
  String get printMarginNone => 'None';

  @override
  String get printPaper => 'Paper';

  @override
  String get printAutoOrientation => 'Turn the paper to match each page';

  @override
  String printPageCount(int count) {
    return '$count to print';
  }

  @override
  String printPreviewNote(int count) {
    return 'The preview shows the first $count pages';
  }

  @override
  String get printPreviewing => 'Preparing preview…';

  @override
  String get printFailed => 'Could not prepare printing';

  @override
  String get printNextStep =>
      'Printer, copies, duplex and colour are set in the system print window that opens next.';

  @override
  String get printContinue => 'Open print window';

  @override
  String get printPerSheet => 'Pages per sheet';

  @override
  String printPerSheetValue(int n) {
    return '$n';
  }

  @override
  String get printBooklet => 'Booklet (fold and staple)';

  @override
  String get printBookletHint =>
      'Print double-sided (flip on short edge) and fold in half. The page count is padded to a multiple of 4 with blank pages.';

  @override
  String get printSheetBorder => 'Draw a border around each page';

  @override
  String get printNumbers => 'Page numbers';

  @override
  String get printNumbersNone => 'None';

  @override
  String get printNumbersBottomCenter => 'Bottom centre';

  @override
  String get printNumbersBottomRight => 'Bottom right';

  @override
  String get printNumbersBottomLeft => 'Bottom left';

  @override
  String get printNumbersTopRight => 'Top right';

  @override
  String get printNumberTotal => 'Include the total (3 / 12)';

  @override
  String get printWatermark => 'Watermark text';

  @override
  String get printWatermarkHint => 'e.g. Copy, Confidential, DRAFT';

  @override
  String get printGrayscale => 'Force black and white';

  @override
  String get printGrayscaleHint =>
      'Pages are turned into grey images, so text becomes an image too. This is slower and the job can be larger.';

  @override
  String viewerSearchTip(String shortcut) {
    return 'Search ($shortcut)';
  }

  @override
  String get searchHint => 'Find in this PDF';

  @override
  String get searchNoResults => 'No results';

  @override
  String searchCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get searchPrev => 'Previous result';

  @override
  String get searchNext => 'Next result';

  @override
  String get searchClose => 'Close search';

  @override
  String get searchSearching => 'Searching…';

  @override
  String get sidebarPages => 'Pages';

  @override
  String get sidebarOutline => 'Outline';

  @override
  String get viewerFit => 'Fit';

  @override
  String get viewerFitWidth => 'Fit width';

  @override
  String get viewerFitPage => 'Fit page';

  @override
  String get viewerActualSize => 'Actual size (100%)';

  @override
  String get passwordTitle => 'Password required';

  @override
  String passwordBody(String name) {
    return '$name is protected by a password.';
  }

  @override
  String get passwordWrong => 'That password is not correct. Try again.';

  @override
  String get passwordHint => 'Password';

  @override
  String get passwordShow => 'Show password';

  @override
  String get passwordHide => 'Hide password';

  @override
  String get passwordOpen => 'Open';

  @override
  String get viewerCopy => 'Copy';

  @override
  String get homeMobileOpenTitle => 'Open a PDF';

  @override
  String get homeMobileOpenHint => 'Pick a file from this device or the cloud';

  @override
  String get homeMobileEmptyTitle => 'Open a PDF to read and take notes';

  @override
  String get homeMobileEmptyHint =>
      'You can also tap a PDF in the Files app or another app and open it here';

  @override
  String homeRecentMeta(String date, String size) {
    return '$date · $size';
  }

  @override
  String get annotHintNoteTouch => 'Tap the page to place a note';

  @override
  String get annotHintInkFinger =>
      'Draw with one finger, move and zoom with two';

  @override
  String get annotHintInkPen =>
      'Draw with the pen, move and zoom with your fingers';

  @override
  String get annotHintShapeTouch => 'Drag to draw the shape';

  @override
  String get annotWidth => 'Line width';

  @override
  String get annotWidthThin => 'Thin';

  @override
  String get annotWidthMedium => 'Medium';

  @override
  String get annotWidthThick => 'Thick';

  @override
  String get annotFingerDraws => 'Draw with finger';

  @override
  String get annotPenOnly => 'Pen only';

  @override
  String get annotFingerDrawsTip =>
      'On: fingers draw too. Off: only the pen draws and fingers move the page';
}
