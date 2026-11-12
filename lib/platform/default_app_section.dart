import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_identity.dart';
import '../home/open_files.dart';
import '../l10n/app_localizations.dart';

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Windows 설정 앱에서 이 앱의 "기본 앱" 페이지를 연다. 설치 프로그램(`installer/windows/app.iss`)이
/// `RegisteredApplications`에 올려 둔 이름으로 찾는다 — 관리자 설치면 HKLM, 아니면 HKCU.
/// 등록돼 있지 않으면(설치 프로그램 없이 실행) false.
@visibleForTesting
Future<bool> openWindowsDefaultAppsPage({ProcessRunner? run, Future<bool> Function(Uri uri)? launch}) async {
  final runner = run ?? Process.run;
  final open = launch ?? launchUrl;
  const name = AppIdentity.displayName;
  for (final (root, parameter) in const [('HKLM', 'registeredAppMachine'), ('HKCU', 'registeredAppUser')]) {
    final ProcessResult result;
    try {
      result = await runner('reg', ['query', '$root\\Software\\RegisteredApplications', '/v', name]);
    } on ProcessException {
      return false;
    }
    if (result.exitCode == 0) {
      return open(Uri.parse('ms-settings:defaultapps?$parameter=${Uri.encodeComponent(name)}'));
    }
  }
  return false;
}

/// 설정의 "기본 앱" 구역 (외형 다음의 앱 고유 구역, settings-screen.md §3). 데스크톱에서만 보인다.
/// 앱이 기본 앱을 코드로 바꾸지는 않는다 — 운영체제가 막거나(Windows) 사용자 선택이라서, 고르는 방법만 안내한다.
/// - Windows: 설정 앱의 Daylight PDF 페이지를 여는 단추, 따라 할 단계, 눌러서 복사하는 형식 칩.
/// - macOS·Linux: 고르는 방법 한 문단.
class DefaultAppSection extends StatefulWidget {
  const DefaultAppSection({super.key, this.openSettings});

  /// 시험용: Windows 설정 열기를 바꿔 끼운다.
  final Future<bool> Function()? openSettings;

  @override
  State<DefaultAppSection> createState() => _DefaultAppSectionState();
}

class _DefaultAppSectionState extends State<DefaultAppSection> {
  bool _busy = false;
  String? _status;
  bool _statusIsError = false;

  Future<void> _openSettings() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _status = null;
    });
    final opened = await (widget.openSettings ?? openWindowsDefaultAppsPage)();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = opened ? null : l10n.defaultAppNotRegisteredWindows;
      _statusIsError = !opened;
    });
  }

  Future<void> _copy(String fileType) async {
    final message = AppLocalizations.of(context).defaultAppCopied(fileType);
    await Clipboard.setData(ClipboardData(text: fileType));
    if (!mounted) return;
    setState(() {
      _status = message;
      _statusIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final isWindows = platform == TargetPlatform.windows;
    if (!isWindows && platform != TargetPlatform.macOS && platform != TargetPlatform.linux) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final status = _status;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsSectionDefaultApp, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Text(isWindows ? l10n.defaultAppDescriptionWindows : l10n.defaultAppDescription, style: small),
        const SizedBox(height: 12),
        if (isWindows) ...[
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _openSettings,
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l10n.defaultAppOpenSettingsButton),
          ),
          const SizedBox(height: 16),
          _WindowsGuide(onCopy: _copy),
        ] else
          Text(platform == TargetPlatform.macOS ? l10n.defaultAppMacSteps : l10n.defaultAppLinuxSteps, style: small),
        if (status != null) ...[
          const SizedBox(height: 8),
          Text(
            status,
            style: small?.copyWith(color: _statusIsError ? theme.colorScheme.error : theme.colorScheme.primary),
          ),
        ],
      ],
    );
  }
}

/// Windows에서 설정 앱으로 할 일. 페이지 맨 위 "기본값 설정"은 등록한 형식(이미지 포함)을 모두 바꾸므로
/// PDF는 형식별로 고르도록 안내하고, 형식은 보기용·변환용으로 나눠 칩으로 보인다.
class _WindowsGuide extends StatelessWidget {
  const _WindowsGuide({required this.onCopy});

  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final steps = [
      l10n.defaultAppWindowsStep1,
      l10n.defaultAppWindowsStep2,
      l10n.defaultAppWindowsStep3,
      l10n.defaultAppWindowsStep4,
    ];
    Widget chips(List<String> extensions) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final ext in extensions)
          ActionChip(
            avatar: const Icon(Icons.content_copy_rounded, size: 14),
            label: Text('.$ext'),
            tooltip: l10n.defaultAppCopyTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: () => onCopy('.$ext'),
          ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 20, child: Text('${index + 1}.', style: small)),
                Expanded(child: Text(step, style: small)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(l10n.defaultAppViewTypesLabel, style: small),
        const SizedBox(height: 8),
        chips(viewerExtensions),
        const SizedBox(height: 12),
        Text(l10n.defaultAppConvertTypesLabel, style: small),
        const SizedBox(height: 8),
        chips(convertExtensions),
      ],
    );
  }
}
