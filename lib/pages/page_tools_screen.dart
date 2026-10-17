import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../window/focus_tint.dart';
import 'edit_tab.dart';
import 'merge_tab.dart';
import 'split_tab.dart';

/// 페이지 도구: 편집(재배열·회전·삭제·추출), 합치기, 나누기. 탭은 위쪽 알약 선택 단추로 고른다.
/// 탭 내용은 모두 만들어 두고 보이기만 바꾸므로 탭을 오가도 하던 일이 남아 있다.
class PageToolsScreen extends StatefulWidget {
  const PageToolsScreen({super.key, this.initialPath});

  /// 편집 탭에서 바로 열 PDF (보기 화면에서 넘어올 때).
  final String? initialPath;

  @override
  State<PageToolsScreen> createState() => _PageToolsScreenState();
}

class _PageToolsScreenState extends State<PageToolsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: Text(l10n.pagesTitle),
        actions: const [SizedBox(width: AppSpacing.sm)],
      ),
      body: Column(
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: 0,
                          icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                          label: Text(l10n.pagesTabEdit),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: const Icon(Icons.library_add_outlined, size: 18),
                          label: Text(l10n.pagesTabMerge),
                        ),
                        ButtonSegment(
                          value: 2,
                          icon: const Icon(Icons.call_split_rounded, size: 18),
                          label: Text(l10n.pagesTabSplit),
                        ),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (s) => setState(() => _tab = s.first),
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                EditTab(initialPath: widget.initialPath),
                const MergeTab(),
                const SplitTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
