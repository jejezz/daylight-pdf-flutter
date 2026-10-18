import 'package:flutter/material.dart';

import '../engine/annotations/pdfium_annotations.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'annotation_state.dart';

/// [query]가 내용에 들어 있는 주석만 (대소문자 무시, 앞뒤 공백 무시). 비어 있으면 전부.
List<ReadAnnotation> filterAnnotations(List<ReadAnnotation> items, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return items;
  return [
    for (final a in items)
      if (a.contents.toLowerCase().contains(q)) a,
  ];
}

/// 문서의 주석 목록(카드): 메모 내용으로 거를 수 있고, 누르면 그 쪽으로 가고, 휴지통으로 지운다.
class AnnotationPanel extends StatefulWidget {
  const AnnotationPanel({
    super.key,
    required this.state,
    required this.onJump,
    required this.onOpenNote,
    required this.onDelete,
  });

  final AnnotationState state;
  final void Function(int pageNumber) onJump;

  /// 메모 행을 눌렀을 때: 내용을 읽고 고칠 수 있는 창을 연다.
  final void Function(ReadAnnotation note) onOpenNote;
  final void Function(ReadAnnotation annotation) onDelete;

  @override
  State<AnnotationPanel> createState() => _AnnotationPanelState();

  static (IconData, String Function(AppLocalizations)) _kind(int subtype) => switch (subtype) {
    9 => (Icons.border_color_rounded, (l) => l.annotTypeHighlight),
    10 => (Icons.format_underlined_rounded, (l) => l.annotTypeUnderline),
    1 => (Icons.sticky_note_2_outlined, (l) => l.annotTypeNote),
    15 => (Icons.gesture_rounded, (l) => l.annotTypeInk),
    5 => (Icons.crop_square_rounded, (l) => l.annotTypeRectangle),
    6 => (Icons.circle_outlined, (l) => l.annotTypeCircle),
    _ => (Icons.comment_outlined, (l) => l.annotTypeOther),
  };
}

class _AnnotationPanelState extends State<AnnotationPanel> {
  final _query = TextEditingController();

  AnnotationState get state => widget.state;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final all = state.items;
        final items = filterAnnotations(all, _query.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
              child: Text(l10n.annotListTitle, style: theme.textTheme.titleSmall),
            ),
            if (all.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.annotFilterHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.annotFilterClear,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(_query.clear),
                          ),
                  ),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        all.isEmpty ? l10n.annotEmpty : l10n.annotFilterNone,
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final a = items[i];
                        final (icon, name) = AnnotationPanel._kind(a.subtype);
                        return GlassCard(
                          radius: AppRadius.button + 4,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.xs,
                            AppSpacing.sm,
                          ),
                          onTap: () => a.subtype == 1 ? widget.onOpenNote(a) : widget.onJump(a.pageIndex + 1),
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
                                      maxLines: a.subtype == 1 ? 3 : 2,
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
                                onPressed: state.busy ? null : () => widget.onDelete(a),
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
