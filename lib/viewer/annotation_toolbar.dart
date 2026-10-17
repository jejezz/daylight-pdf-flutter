import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'annotation_state.dart';

/// 주석 도구 줄: 형광펜·밑줄(선택한 글자에 적용), 메모·손글씨·사각형·원(쪽에 그리기), 색, 목록.
class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({
    super.key,
    required this.state,
    required this.onHighlight,
    required this.onUnderline,
    required this.showList,
    required this.onToggleList,
  });

  final AnnotationState state;
  final VoidCallback onHighlight;
  final VoidCallback onUnderline;
  final bool showList;
  final VoidCallback onToggleList;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        Widget tool(DrawTool t, IconData icon, String tip) => IconButton(
          tooltip: tip,
          isSelected: state.tool == t,
          icon: Icon(icon),
          style: state.tool == t
              ? IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primaryContainer)
              : null,
          onPressed: () => state.toggleTool(t),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.annotHighlight,
                icon: const Icon(Icons.border_color_rounded),
                onPressed: onHighlight,
              ),
              IconButton(
                tooltip: l10n.annotUnderline,
                icon: const Icon(Icons.format_underlined_rounded),
                onPressed: onUnderline,
              ),
              const SizedBox(height: 24, child: VerticalDivider()),
              tool(DrawTool.note, Icons.sticky_note_2_outlined, l10n.annotNote),
              tool(DrawTool.ink, Icons.gesture_rounded, l10n.annotInk),
              tool(DrawTool.rectangle, Icons.crop_square_rounded, l10n.annotRectangle),
              tool(DrawTool.circle, Icons.circle_outlined, l10n.annotCircle),
              const SizedBox(height: 24, child: VerticalDivider()),
              for (final c in AnnotationState.palette)
                Tooltip(
                  message: l10n.annotColor,
                  child: InkResponse(
                    onTap: () => state.setColor(c),
                    radius: 16,
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: state.color == c ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: l10n.annotList,
                isSelected: showList,
                icon: const Icon(Icons.format_list_bulleted_rounded),
                style: showList
                    ? IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primaryContainer)
                    : null,
                onPressed: onToggleList,
              ),
            ],
          ),
        );
      },
    );
  }
}
