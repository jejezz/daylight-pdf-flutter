import 'package:flutter/material.dart';

import '../engine/annotations/pdfium_annotations.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'annotation_state.dart';

/// 문서의 주석 목록(카드): 누르면 그 쪽으로 가고, 휴지통으로 지운다.
class AnnotationPanel extends StatelessWidget {
  const AnnotationPanel({super.key, required this.state, required this.onJump, required this.onDelete});

  final AnnotationState state;
  final void Function(int pageNumber) onJump;
  final void Function(ReadAnnotation annotation) onDelete;

  static (IconData, String Function(AppLocalizations)) _kind(int subtype) => switch (subtype) {
    9 => (Icons.border_color_rounded, (l) => l.annotTypeHighlight),
    10 => (Icons.format_underlined_rounded, (l) => l.annotTypeUnderline),
    1 => (Icons.sticky_note_2_outlined, (l) => l.annotTypeNote),
    15 => (Icons.gesture_rounded, (l) => l.annotTypeInk),
    5 => (Icons.crop_square_rounded, (l) => l.annotTypeRectangle),
    6 => (Icons.circle_outlined, (l) => l.annotTypeCircle),
    _ => (Icons.comment_outlined, (l) => l.annotTypeOther),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final items = state.items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
              child: Text(l10n.annotListTitle, style: theme.textTheme.titleSmall),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text(l10n.annotEmpty, style: theme.textTheme.bodySmall))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final a = items[i];
                        final (icon, name) = _kind(a.subtype);
                        return GlassCard(
                          radius: AppRadius.button + 4,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.xs,
                            AppSpacing.sm,
                          ),
                          onTap: () => onJump(a.pageIndex + 1),
                          child: Row(
                            children: [
                              Icon(icon, size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.contents.isEmpty ? name(l10n) : a.contents,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    Text(
                                      a.contents.isEmpty
                                          ? l10n.pagesPageLabel(a.pageIndex + 1)
                                          : '${name(l10n)} · ${l10n.pagesPageLabel(a.pageIndex + 1)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.annotDelete,
                                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                onPressed: state.busy ? null : () => onDelete(a),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
