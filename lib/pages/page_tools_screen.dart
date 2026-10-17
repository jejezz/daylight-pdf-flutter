import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../window/focus_tint.dart';
import 'edit_tab.dart';
import 'merge_tab.dart';
import 'split_tab.dart';
import '../theme/app_theme.dart';

/// 페이지 도구: 편집(재배열·회전·삭제·추출), 합치기, 나누기.
class PageToolsScreen extends StatelessWidget {
  const PageToolsScreen({super.key, this.initialPath});

  /// 편집 탭에서 바로 열 PDF (보기 화면에서 넘어올 때).
  final String? initialPath;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: const FocusTint(),
          title: Text(l10n.pagesTitle),
          actions: const [SizedBox(width: AppSpacing.sm)],
        ),
        body: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: l10n.pagesTabEdit),
                Tab(text: l10n.pagesTabMerge),
                Tab(text: l10n.pagesTabSplit),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  EditTab(initialPath: initialPath),
                  const MergeTab(),
                  const SplitTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
