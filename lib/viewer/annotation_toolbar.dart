import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/status_pill.dart';
import '../widgets/tool_chip.dart';
import 'annotation_state.dart';

/// 주석 도구 줄: [형광펜·밑줄: 선택한 글자에 적용] | [메모·손글씨·사각형·원: 쪽에 그리기] | 색 | 켜진 도구 안내 | 주석 목록.
/// 폭이 좁으면 글자를 숨기고 아이콘만 둔다 (툴팁은 항상 있다).
class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({
    super.key,
    required this.state,
    required this.onHighlight,
    required this.onUnderline,
    required this.showList,
    required this.onToggleList,
    required this.onUndo,
    required this.undoShortcut,
  });

  final AnnotationState state;
  final VoidCallback onHighlight;
  final VoidCallback onUnderline;
  final bool showList;
  final VoidCallback onToggleList;
  final VoidCallback onUndo;

  /// 툴팁에 보여 줄 단축키 글자 (⌘Z / Ctrl+Z).
  final String undoShortcut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1040;
        return ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            Widget tool(DrawTool t, IconData icon, String label, String tip) => ToolChip(
              icon: icon,
              label: label,
              tooltip: tip,
              compact: compact,
              selected: state.tool == t,
              onPressed: () => state.toggleTool(t),
            );
            final hint = switch (state.tool) {
              DrawTool.note => l10n.annotHintNote,
              DrawTool.ink => l10n.annotHintInk,
              DrawTool.rectangle || DrawTool.circle => l10n.annotHintShape,
              DrawTool.none => null,
            };
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  ToolChip(
                    icon: Icons.border_color_rounded,
                    label: l10n.annotTypeHighlight,
                    tooltip: l10n.annotHighlight,
                    compact: compact,
                    onPressed: onHighlight,
                  ),
                  ToolChip(
                    icon: Icons.format_underlined_rounded,
                    label: l10n.annotTypeUnderline,
                    tooltip: l10n.annotUnderline,
                    compact: compact,
                    onPressed: onUnderline,
                  ),
                  const _Gap(),
                  tool(DrawTool.note, Icons.sticky_note_2_outlined, l10n.annotTypeNote, l10n.annotNote),
                  tool(DrawTool.ink, Icons.gesture_rounded, l10n.annotTypeInk, l10n.annotInk),
                  tool(DrawTool.rectangle, Icons.crop_square_rounded, l10n.annotTypeRectangle, l10n.annotRectangle),
                  tool(DrawTool.circle, Icons.circle_outlined, l10n.annotTypeCircle, l10n.annotCircle),
                  const _Gap(),
                  _Swatches(state: state, tooltip: l10n.annotColor),
                  const _Gap(),
                  ToolChip(
                    icon: Icons.undo_rounded,
                    label: l10n.annotUndo,
                    tooltip: l10n.annotUndoTip(undoShortcut),
                    compact: compact,
                    onPressed: state.canUndo && !state.busy ? onUndo : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: hint == null
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: StatusPill(label: hint, tone: PillTone.info, icon: Icons.touch_app_outlined),
                          ),
                  ),
                  ToolChip(
                    icon: Icons.format_list_bulleted_rounded,
                    label: l10n.annotListLabel(state.items.length),
                    tooltip: l10n.annotList,
                    compact: compact,
                    selected: showList,
                    onPressed: onToggleList,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    child: SizedBox(height: 22, child: VerticalDivider(color: Theme.of(context).colorScheme.outlineVariant)),
  );
}

/// 색 고르기: 알약 안에 색 점 여섯 개. 고른 색은 테두리로 표시한다.
class _Swatches extends StatelessWidget {
  const _Swatches({required this.state, required this.tooltip});

  final AnnotationState state;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in AnnotationState.palette)
            Tooltip(
              message: tooltip,
              child: InkResponse(
                onTap: () => state.setColor(c),
                radius: 16,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(color: state.color == c ? scheme.onSurface : Colors.transparent, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
