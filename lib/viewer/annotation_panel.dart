import 'package:flutter/material.dart';

import '../engine/annotations/pdfium_annotations.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'annotation_state.dart';

/// 문서의 주석 목록: 누르면 그 쪽으로 가고, 지우기 단추로 삭제한다.
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
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final items = state.items;
        if (items.isEmpty) {
          return Center(child: Text(l10n.annotEmpty));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.sm),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final a = items[i];
            final (icon, name) = _kind(a.subtype);
            return ListTile(
              dense: true,
              leading: Icon(icon),
              title: Text(a.contents.isEmpty ? name(l10n) : a.contents, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                a.contents.isEmpty
                    ? l10n.pagesPageLabel(a.pageIndex + 1)
                    : '${name(l10n)} · ${l10n.pagesPageLabel(a.pageIndex + 1)}',
              ),
              onTap: () => onJump(a.pageIndex + 1),
              trailing: IconButton(
                tooltip: l10n.annotDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: state.busy ? null : () => onDelete(a),
              ),
            );
          },
        );
      },
    );
  }
}
