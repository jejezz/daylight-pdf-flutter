; Inno Setup script template for a Flutter Windows desktop app
; (jejezz/application-release-templates desktop/ @ conventions-v1).
;
; Run by .github/workflows/release.yml's `build-windows` job on every
; `vX.Y.Z` tag push, which passes MyAppName / MyFileName / MyAppVersion /
; MyAppNumericVersion / MyAppExeName via `ISCC /D...` (read from the tag,
; AppInfo.xcconfig and windows/CMakeLists.txt). The fallbacks below are only
; for a local, manual compile — MyAppVersion 0.0.0 marks such a build.
;
; Edit by hand, once per app:
;   1. AppId — a fresh GUID (PowerShell: `[guid]::NewGuid()`). Never reuse
;      another app's GUID, and never change it after the first release, or
;      Windows treats the next version as a different application (breaking
;      upgrade/uninstall). conventions/identity.md §5.
;   2. MyAppURL — this app's GitHub repository (conventions/identity.md §1).

#ifndef MyAppName
  #define MyAppName "__APP_DISPLAY_NAME__"
#endif
#ifndef MyFileName
  #define MyFileName "__APP_FILE_NAME__"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef MyAppNumericVersion
  #define MyAppNumericVersion "0.0.0"
#endif
#ifndef MyAppExeName
  #define MyAppExeName "__APP_EXE_NAME__.exe"
#endif
#define MyAppPublisher "Jongyun Ahn"
#define MyAppURL "https://github.com/jejezz/daylight-pdf-flutter"
; The app's first release year — edit it for apps started after 2026.
#define MyFirstReleaseYear "2026"
#define SourceDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{D43E7915-645E-4683-831D-3D0E9653655A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
AppCopyright=Copyright (C) {#MyFirstReleaseYear} {#MyAppPublisher}
VersionInfoVersion={#MyAppNumericVersion}
VersionInfoProductName={#MyAppName}
VersionInfoCompany={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename={#MyFileName}-{#MyAppVersion}-windows-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; The [Registry] file types below: let Explorer refresh associations and icons.
ChangesAssociations=yes
; No license page: MIT apps have nothing to agree to (conventions/licensing.md §4).

[Languages]
; Installer text comes from Inno Setup's own translations — don't hardcode
; Korean (or English) strings below (conventions/packaging.md §3).
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; File types. Keep in sync with lib/home/open_files.dart (isOpenableFile),
; macos/Runner/Info.plist (CFBundleDocumentTypes) and the Linux .desktop MimeType
; in .github/workflows/release.yml.
; This registers the app as a *candidate* handler: it shows up under "Open with" and
; in Settings > Apps > Default apps. Windows 10+ does not let an installer make itself
; the default (the user's choice is protected), so the user picks it there.
; A PDF opens in the viewer; the other types open in the Convert screen.
; Uninstall removes everything written here.
#define AppProgPdf "DaylightPDF.Document"
#define AppProgConvert "DaylightPDF.Convertible"
#define AppCapabilities "Software\" + MyAppPublisher + "\" + MyAppName + "\Capabilities"

[Registry]
; ProgIDs
Root: HKA; Subkey: "Software\Classes\{#AppProgPdf}"; ValueType: string; ValueName: ""; ValueData: "PDF Document"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#AppProgPdf}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\{#AppProgPdf}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
Root: HKA; Subkey: "Software\Classes\{#AppProgConvert}"; ValueType: string; ValueName: ""; ValueData: "Convert to PDF"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#AppProgConvert}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\{#AppProgConvert}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
; Settings > Default apps
Root: HKA; Subkey: "Software\{#MyAppPublisher}"; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "{#AppCapabilities}"; ValueType: string; ValueName: "ApplicationName"; ValueData: "{#MyAppName}"
Root: HKA; Subkey: "{#AppCapabilities}"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "{#MyAppName}"
Root: HKA; Subkey: "{#AppCapabilities}"; ValueType: string; ValueName: "ApplicationIcon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\RegisteredApplications"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: "{#AppCapabilities}"; Flags: uninsdeletevalue
; "Open with" entry for the exe itself
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#MyAppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
; Per extension
Root: HKA; Subkey: "Software\Classes\.pdf\OpenWithProgids"; ValueType: string; ValueName: "{#AppProgPdf}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "{#AppCapabilities}\FileAssociations"; ValueType: string; ValueName: ".pdf"; ValueData: "{#AppProgPdf}"
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".pdf"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\.ai\OpenWithProgids"; ValueType: string; ValueName: "{#AppProgConvert}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "{#AppCapabilities}\FileAssociations"; ValueType: string; ValueName: ".ai"; ValueData: "{#AppProgConvert}"
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".ai"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\.svg\OpenWithProgids"; ValueType: string; ValueName: "{#AppProgConvert}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "{#AppCapabilities}\FileAssociations"; ValueType: string; ValueName: ".svg"; ValueData: "{#AppProgConvert}"
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".svg"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\.png\OpenWithProgids"; ValueType: string; ValueName: "{#AppProgConvert}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "{#AppCapabilities}\FileAssociations"; ValueType: string; ValueName: ".png"; ValueData: "{#AppProgConvert}"
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".png"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\.jpg\OpenWithProgids"; ValueType: string; ValueName: "{#AppProgConvert}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "{#AppCapabilities}\FileAssociations"; ValueType: string; ValueName: ".jpg"; ValueData: "{#AppProgConvert}"
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".jpg"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\.jpeg\OpenWithProgids"; ValueType: string; ValueName: "{#AppProgConvert}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "{#AppCapabilities}\FileAssociations"; ValueType: string; ValueName: ".jpeg"; ValueData: "{#AppProgConvert}"
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".jpeg"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\.bmp\OpenWithProgids"; ValueType: string; ValueName: "{#AppProgConvert}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "{#AppCapabilities}\FileAssociations"; ValueType: string; ValueName: ".bmp"; ValueData: "{#AppProgConvert}"
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".bmp"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\.gif\OpenWithProgids"; ValueType: string; ValueName: "{#AppProgConvert}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "{#AppCapabilities}\FileAssociations"; ValueType: string; ValueName: ".gif"; ValueData: "{#AppProgConvert}"
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".gif"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\.webp\OpenWithProgids"; ValueType: string; ValueName: "{#AppProgConvert}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "{#AppCapabilities}\FileAssociations"; ValueType: string; ValueName: ".webp"; ValueData: "{#AppProgConvert}"
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".webp"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\.tif\OpenWithProgids"; ValueType: string; ValueName: "{#AppProgConvert}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "{#AppCapabilities}\FileAssociations"; ValueType: string; ValueName: ".tif"; ValueData: "{#AppProgConvert}"
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".tif"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\.tiff\OpenWithProgids"; ValueType: string; ValueName: "{#AppProgConvert}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "{#AppCapabilities}\FileAssociations"; ValueType: string; ValueName: ".tiff"; ValueData: "{#AppProgConvert}"
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".tiff"; ValueData: ""

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
