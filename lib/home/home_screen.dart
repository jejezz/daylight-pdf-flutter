import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app_identity.dart';
import '../l10n/app_localizations.dart';
import '../settings/settings_menus.dart';
import '../theme/app_theme.dart';
import '../viewer/viewer_screen.dart';
import '../window/focus_tint.dart';

bool isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');

/// 시작 화면 — 빈 상태 패턴 (ui-ux.md §6). PDF를 열거나 끌어다 놓으면 보기 화면으로 간다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onAbout});

  final VoidCallback onAbout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _dragging = false;

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final file = await openFile(
      acceptedTypeGroups: [XTypeGroup(label: l10n.fileTypePdf, extensions: const ['pdf'])],
    );
    if (file != null && mounted) _open(file.path);
  }

  void _open(String path) {
    if (!isPdfPath(path)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).openPdfOnly)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ViewerScreen(path: path)));
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
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: (details) {
          setState(() => _dragging = false);
          if (details.files.isNotEmpty) _open(details.files.first.path);
        },
        child: Container(
          color: _dragging ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(AppIdentity.iconAsset, width: 48, height: 48),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.homeEmptyTitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(onPressed: _pick, child: Text(l10n.homeEmptyAction)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
