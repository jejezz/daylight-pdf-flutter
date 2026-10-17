import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app_identity.dart';
import '../convert/convert_screen.dart';
import '../l10n/app_localizations.dart';
import '../pages/page_tools_screen.dart';
import '../settings/settings_menus.dart';
import '../theme/app_theme.dart';
import '../viewer/viewer_screen.dart';
import '../widgets/drop_zone.dart';
import '../widgets/glass_card.dart';
import '../window/focus_tint.dart';

bool isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');

/// 시작 화면: 큰 끌어놓기 영역(창의 대부분이 드롭 영역) + 변환·페이지 도구로 가는 카드.
/// PDF 한 개를 놓으면 보기로, 그 밖의 파일은 변환 화면으로 간다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onAbout});

  final VoidCallback onAbout;

  Future<void> _pick(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: l10n.fileTypePdf, extensions: const ['pdf']),
      ],
    );
    if (file != null && context.mounted) _open(context, file.path);
  }

  void _open(BuildContext context, String path) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ViewerScreen(path: path)));

  void _openConvert(BuildContext context, [List<String> paths = const []]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ConvertScreen(initialPaths: paths)));

  void _openPages(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PageToolsScreen()));

  void _handleDrop(BuildContext context, List<String> paths) {
    if (paths.length == 1 && isPdfPath(paths.first)) {
      _open(context, paths.first);
    } else {
      _openConvert(context, paths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: const Text(AppIdentity.displayName),
        actions: [
          const ThemeMenuButton(),
          const LanguageMenuButton(),
          IconButton(tooltip: l10n.aboutTooltip, icon: const Icon(Icons.info_outline_rounded), onPressed: onAbout),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      child: Image.asset(AppIdentity.iconAsset, width: 56, height: 56),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppIdentity.displayName, style: theme.textTheme.headlineMedium),
                          const SizedBox(height: 2),
                          Text(l10n.aboutTagline, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Expanded(
                  child: DropZone(
                    onDrop: (paths) => _handleDrop(context, paths),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.upload_file_rounded, size: 44, color: theme.colorScheme.primary),
                          const SizedBox(height: AppSpacing.md),
                          Text(l10n.homeEmptyTitle, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.xs),
                          Text(l10n.homeDropSubtitle, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton.icon(
                            onPressed: () => _pick(context),
                            icon: const Icon(Icons.folder_open_rounded, size: 18),
                            label: Text(l10n.homeEmptyAction),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.swap_horiz_rounded,
                        title: l10n.homeConvertAction,
                        hint: l10n.homeConvertHint,
                        onTap: () => _openConvert(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.dashboard_customize_outlined,
                        title: l10n.homePagesAction,
                        hint: l10n.homePagesHint,
                        onTap: () => _openPages(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.hint, required this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      onTap: onTap,
      radius: AppRadius.tile,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(hint, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
