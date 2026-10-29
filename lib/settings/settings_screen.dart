import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'settings_menus.dart';

/// 설정 화면: 모바일(Android 태블릿)까지 지원하는 앱이라 전체 페이지로 민다
/// (settings-screen.md §1). 데스크톱 전용 앱은 AlertDialog를 쓴다 — 이 앱은 그 예외다.
Future<void> showSettingsDialog(BuildContext context) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const SettingsScreen()));

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsSectionAppearance, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(l10n.settingsMode, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            const ModeSegmentedButton(),
            const SizedBox(height: 20),
            Text(l10n.settingsPalette, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            const AccentPaletteChips(),
            const SizedBox(height: 20),
            Text(l10n.languageMenuTooltip, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            const LanguageSegmentedButton(),
          ],
        ),
      ),
    );
  }
}
