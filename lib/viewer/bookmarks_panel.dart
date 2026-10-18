import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 사이드바의 북마크 목록: 쪽 번호 순. 누르면 [onTap]으로 그 쪽으로 옮기고, 휴지통으로 지운다.
class BookmarksPanel extends StatelessWidget {
  const BookmarksPanel({
    super.key,
    required this.pages,
    required this.current,
    required this.onTap,
    required this.onDelete,
  });

  final List<int> pages;
  final int current;
  final void Function(int page) onTap;
  final void Function(int page) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (pages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          l10n.bookmarksEmpty,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: pages.length,
      itemBuilder: (context, i) {
        final page = pages[i];
        return InkWell(
          onTap: () => onTap(page),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.xs, 0),
            child: Row(
              children: [
                Icon(Icons.bookmark_rounded, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.bookmarkPage(page),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: page == current ? FontWeight.w700 : null),
                  ),
                ),
                IconButton(
                  tooltip: l10n.bookmarkDelete,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => onDelete(page),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
