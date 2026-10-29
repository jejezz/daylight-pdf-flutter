import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../app_identity.dart';
import '../convert/convert_screen.dart';
import '../l10n/app_localizations.dart';
import '../pages/page_tools_screen.dart';
import '../platform/platform_kind.dart';
import '../settings/settings_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/drop_zone.dart';
import '../widgets/glass_card.dart';
import '../widgets/tool_chip.dart';
import '../window/focus_tint.dart';
import 'open_pdf.dart';
import 'recent_files.dart';

/// 홈 화면이 보기 화면에서 돌아왔을 때 최근 목록을 다시 읽도록 알아채는 관찰자 (다른 앱이 연 PDF가 목록에 생겼을 수 있다).
final RouteObserver<ModalRoute<void>> homeRouteObserver = RouteObserver<ModalRoute<void>>();

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

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) homeRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    homeRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// 위에 올라와 있던 화면(보기)이 닫혀 홈이 다시 보일 때.
  @override
  void didPopNext() => _reload();

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
    await openPdf(Navigator.of(context), path, recents: widget.recents);
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

  /// 폰·태블릿 시작 화면: 큰 "PDF 열기" 카드 하나와 최근 파일. 끌어놓기, 변환, 페이지 도구는 없다 (읽기와 메모 중심).
  Widget _mobile(AppLocalizations l10n, ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppIdentity.displayName),
        actions: [
          IconButton(
            tooltip: l10n.settingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showSettingsDialog(context),
          ),
          IconButton(
            tooltip: l10n.aboutTooltip,
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: widget.onAbout,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 860 ? 3 : (box.maxWidth >= 560 ? 2 : 1);
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
                      sliver: SliverToBoxAdapter(child: _OpenCard(onTap: _pick)),
                    ),
                    if (_recent.isEmpty)
                      SliverFillRemaining(hasScrollBody: false, child: _MobileEmpty(theme: theme))
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.sm),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Text(l10n.homeRecentTitle, style: theme.textTheme.titleMedium),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _clearRecent,
                                icon: const Icon(Icons.playlist_remove_rounded, size: 20),
                                label: Text(l10n.homeRecentClear),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                        sliver: SliverGrid.builder(
                          itemCount: _recent.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisExtent: 84,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                          ),
                          itemBuilder: (context, i) => _MobileRecentCard(
                            path: _recent[i],
                            onOpen: () => _openRecent(_recent[i]),
                            onRemove: () => _removeRecent(_recent[i]),
                            removeTooltip: l10n.homeRecentRemove,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (isMobilePlatform) return _mobile(l10n, theme);
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: const Text(AppIdentity.displayName),
        actions: [
          IconButton(
            tooltip: l10n.settingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showSettingsDialog(context),
          ),
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
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                    // 너무 낮으면 어디에 놓아야 하는지 헷갈리므로 최소 높이를 둔다.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 96),
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

/// 모바일 시작 화면의 큰 "PDF 열기" 카드 (손가락으로 누르기 쉽게 크게).
class _OpenCard extends StatelessWidget {
  const _OpenCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return GlassCard(
      onTap: onTap,
      radius: AppRadius.card,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(AppRadius.tile),
            ),
            child: Icon(Icons.folder_open_rounded, size: 32, color: theme.colorScheme.onPrimary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.homeMobileOpenTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.homeMobileOpenHint, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// 최근 파일이 아직 없을 때의 안내.
class _MobileEmpty extends StatelessWidget {
  const _MobileEmpty({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note_rounded, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.homeMobileEmptyTitle, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.homeMobileEmptyHint, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// 모바일 최근 파일 카드: 이름과 "날짜 · 크기" (앱 안 보관함 경로는 보여 줘도 쓸모가 없다).
class _MobileRecentCard extends StatelessWidget {
  const _MobileRecentCard({
    required this.path,
    required this.onOpen,
    required this.onRemove,
    required this.removeTooltip,
  });

  final String path;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stat = File(path).statSync();
    final meta = l10n.homeRecentMeta(
      DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(stat.modified),
      formatFileSize(stat.size),
    );
    return GlassCard(
      radius: AppRadius.tile,
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.xs),
      onTap: onOpen,
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf_rounded, size: 30, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.basename(path), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(tooltip: removeTooltip, icon: const Icon(Icons.close_rounded, size: 20), onPressed: onRemove),
        ],
      ),
    );
  }
}

/// 파일 크기를 "1.2 MB"처럼 짧게.
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(bytes < 10 * 1024 ? 1 : 0)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
