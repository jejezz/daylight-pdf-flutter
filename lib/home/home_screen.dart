import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app_identity.dart';
import '../convert/convert_screen.dart';
import '../l10n/app_localizations.dart';
import '../pages/page_tools_screen.dart';
import '../settings/settings_menus.dart';
import '../theme/app_theme.dart';
import '../viewer/viewer_screen.dart';
import '../widgets/drop_zone.dart';
import '../widgets/glass_card.dart';
import '../widgets/tool_chip.dart';
import '../window/focus_tint.dart';
import 'recent_files.dart';

bool isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');

/// 시작 화면: 큰 끌어놓기 영역, 최근 파일, 변환·페이지 도구로 가는 카드.
/// PDF 한 개를 놓으면 보기로, 그 밖의 파일은 변환 화면으로 간다.
class HomeScreen extends StatefulWidget {
  HomeScreen({super.key, required this.onAbout, RecentFiles? recents}) : recents = recents ?? RecentFiles();

  final VoidCallback onAbout;
  final RecentFiles recents;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.recents.loadExisting();
    if (mounted) setState(() => _recent = list);
  }

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: l10n.fileTypePdf, extensions: const ['pdf']),
      ],
    );
    if (file != null && mounted) _open(file.path);
  }

  /// 보기 화면으로 간다. 최근 파일 맨 앞에 올리고, 돌아오면 목록을 새로 읽는다.
  Future<void> _open(String path) async {
    await widget.recents.add(path);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ViewerScreen(path: path)));
    if (mounted) _reload();
  }

  /// 최근 목록의 파일 열기. 그새 사라진 파일이면 알리고 목록에서 뺀다.
  Future<void> _openRecent(String path) async {
    if (!File(path).existsSync()) {
      await widget.recents.remove(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errCannotRead(p.basename(path)))));
      _reload();
      return;
    }
    await _open(path);
  }

  Future<void> _removeRecent(String path) async {
    await widget.recents.remove(path);
    _reload();
  }

  Future<void> _clearRecent() async {
    await widget.recents.clear();
    _reload();
  }

  void _openConvert([List<String> paths = const []]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ConvertScreen(initialPaths: paths)));

  void _openPages() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PageToolsScreen()));

  void _handleDrop(List<String> paths) {
    if (paths.length == 1 && isPdfPath(paths.first)) {
      _open(paths.first);
    } else {
      _openConvert(paths);
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
          IconButton(
            tooltip: l10n.aboutTooltip,
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: widget.onAbout,
          ),
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
                // 최근 파일이 없으면 큰 끌어놓기 영역이 화면을 채우고, 있으면 한 줄짜리로 줄여 목록에 자리를 준다.
                if (_recent.isEmpty)
                  Expanded(
                    child: DropZone(
                      onDrop: _handleDrop,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.upload_file_rounded, size: 44, color: theme.colorScheme.primary),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                l10n.homeEmptyTitle,
                                style: theme.textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                l10n.homeDropSubtitle,
                                style: theme.textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              FilledButton.icon(
                                onPressed: _pick,
                                icon: const Icon(Icons.folder_open_rounded, size: 18),
                                label: Text(l10n.homeEmptyAction),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  DropZone(
                    onDrop: _handleDrop,
                    radius: AppRadius.tile,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(Icons.upload_file_rounded, size: 32, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.homeEmptyTitle, style: theme.textTheme.titleSmall),
                              Text(l10n.homeDropSubtitle, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _pick,
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: Text(l10n.homeEmptyAction),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: _RecentSection(
                      paths: _recent,
                      onOpen: _openRecent,
                      onRemove: _removeRecent,
                      onClear: _clearRecent,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.swap_horiz_rounded,
                        title: l10n.homeConvertAction,
                        hint: l10n.homeConvertHint,
                        onTap: _openConvert,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.dashboard_customize_outlined,
                        title: l10n.homePagesAction,
                        hint: l10n.homePagesHint,
                        onTap: _openPages,
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

/// 최근 파일: 제목 줄(목록 지우기) 아래에 두 열 격자. 칸이 모자라면 격자 안에서 스크롤한다.
class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.paths, required this.onOpen, required this.onRemove, required this.onClear});

  final List<String> paths;
  final void Function(String path) onOpen;
  final void Function(String path) onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(l10n.homeRecentTitle, style: theme.textTheme.titleSmall),
            const Spacer(),
            ToolChip(icon: Icons.playlist_remove_rounded, label: l10n.homeRecentClear, onPressed: onClear),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: GridView.builder(
            itemCount: paths.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 52,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemBuilder: (context, i) => _RecentRow(
              path: paths[i],
              onOpen: () => onOpen(paths[i]),
              onRemove: () => onRemove(paths[i]),
              removeTooltip: l10n.homeRecentRemove,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.path, required this.onOpen, required this.onRemove, required this.removeTooltip});

  final String path;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: path,
      waitDuration: const Duration(milliseconds: 600),
      child: GlassCard(
        radius: AppRadius.button + 4,
        padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
        onTap: onOpen,
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.basename(path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    shortFolder(path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: removeTooltip,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onRemove,
            ),
          ],
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
