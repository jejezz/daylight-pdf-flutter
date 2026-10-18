import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../platform/platform_kind.dart';
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
        final touch = isMobilePlatform;
        // 손가락용은 단추가 커서 더 넓어야 글자가 들어간다
        final compact = constraints.maxWidth < (touch ? 1280 : 1040);
        return ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            Widget tool(DrawTool t, IconData icon, String label, String tip) => ToolChip(
              icon: icon,
              label: label,
              tooltip: tip,
              compact: compact,
              touch: touch,
              selected: state.tool == t,
              onPressed: () => state.toggleTool(t),
            );
            final hint = switch (state.tool) {
              DrawTool.note => touch ? l10n.annotHintNoteTouch : l10n.annotHintNote,
              DrawTool.ink =>
                touch ? (state.fingerDraws ? l10n.annotHintInkFinger : l10n.annotHintInkPen) : l10n.annotHintInk,
              DrawTool.rectangle || DrawTool.circle => touch ? l10n.annotHintShapeTouch : l10n.annotHintShape,
              DrawTool.none => null,
            };
            final drawsLines =
                state.tool == DrawTool.ink || state.tool == DrawTool.rectangle || state.tool == DrawTool.circle;
            // 도구 단추들 (안내 문구와 주석 목록 단추는 따로 놓는다)
            final tools = <Widget>[
              ToolChip(
                icon: Icons.border_color_rounded,
                label: l10n.annotTypeHighlight,
                tooltip: l10n.annotHighlight,
                compact: compact,
                touch: touch,
                onPressed: onHighlight,
              ),
              ToolChip(
                icon: Icons.format_underlined_rounded,
                label: l10n.annotTypeUnderline,
                tooltip: l10n.annotUnderline,
                compact: compact,
                touch: touch,
                onPressed: onUnderline,
              ),
              const _Gap(),
              tool(DrawTool.note, Icons.sticky_note_2_outlined, l10n.annotTypeNote, l10n.annotNote),
              tool(DrawTool.ink, Icons.gesture_rounded, l10n.annotTypeInk, l10n.annotInk),
              tool(DrawTool.rectangle, Icons.crop_square_rounded, l10n.annotTypeRectangle, l10n.annotRectangle),
              tool(DrawTool.circle, Icons.circle_outlined, l10n.annotTypeCircle, l10n.annotCircle),
              const _Gap(),
              _Swatches(state: state, tooltip: l10n.annotColor, touch: touch),
              if (drawsLines) ...[
                const SizedBox(width: AppSpacing.sm),
                _WidthPicker(
                  state: state,
                  tooltip: l10n.annotWidth,
                  labels: [l10n.annotWidthThin, l10n.annotWidthMedium, l10n.annotWidthThick],
                  touch: touch,
                ),
              ],
              if (touch && drawsLines) ...[
                const SizedBox(width: AppSpacing.sm),
                ToolChip(
                  icon: state.fingerDraws ? Icons.touch_app_outlined : Icons.edit_outlined,
                  label: state.fingerDraws ? l10n.annotFingerDraws : l10n.annotPenOnly,
                  tooltip: l10n.annotFingerDrawsTip,
                  compact: compact,
                  touch: true,
                  onPressed: () => state.setFingerDraws(!state.fingerDraws),
                ),
              ],
              const _Gap(),
              ToolChip(
                icon: Icons.undo_rounded,
                label: l10n.annotUndo,
                tooltip: l10n.annotUndoTip(undoShortcut),
                compact: compact,
                touch: touch,
                onPressed: state.canUndo && !state.busy ? onUndo : null,
              ),
            ];
            final listChip = ToolChip(
              icon: Icons.format_list_bulleted_rounded,
              label: l10n.annotListLabel(state.items.length),
              tooltip: l10n.annotList,
              compact: compact,
              touch: touch,
              selected: showList,
              onPressed: onToggleList,
            );
            if (touch) {
              // 손가락용: 단추가 커서 넓은 화면에서도 넘칠 수 있으니 가로로 밀 수 있게 하고, 안내 문구는 도구 줄 아래 가는 줄에 둔다.
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        ...tools,
                        const SizedBox(width: AppSpacing.md),
                        listChip,
                      ],
                    ),
                  ),
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: StatusPill(label: hint, tone: PillTone.info, icon: Icons.touch_app_outlined),
                    ),
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  ...tools,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: hint == null
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: StatusPill(label: hint, tone: PillTone.info, icon: Icons.touch_app_outlined),
                          ),
                  ),
                  listChip,
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
  const _Swatches({required this.state, required this.tooltip, this.touch = false});

  final AnnotationState state;
  final String tooltip;
  final bool touch;

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
                radius: touch ? 24 : 16,
                child: Container(
                  width: touch ? 30 : 20,
                  height: touch ? 30 : 20,
                  margin: EdgeInsets.symmetric(horizontal: touch ? 5 : 3, vertical: touch ? 6 : 0),
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

/// 선 굵기 고르기: 점 세 개(가늘게·보통·굵게). 고른 굵기는 테두리로 표시한다.
class _WidthPicker extends StatelessWidget {
  const _WidthPicker({required this.state, required this.tooltip, required this.labels, required this.touch});

  final AnnotationState state;
  final String tooltip;
  final List<String> labels;
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = touch ? 44.0 : 30.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: touch ? 2 : 0),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < AnnotationState.strokeWidths.length; i++)
            Tooltip(
              message: '$tooltip: ${labels[i]}',
              child: InkResponse(
                onTap: () => state.setWidthIndex(i),
                radius: box / 2,
                child: Container(
                  width: box,
                  height: box,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: state.widthIndex == i ? scheme.primary : Colors.transparent, width: 2),
                  ),
                  // 점의 크기가 곧 굵기 (가늘게 4, 보통 8, 굵게 14)
                  child: Container(
                    width: 4.0 + i * 5 + (i == 2 ? 1 : 0),
                    height: 4.0 + i * 5 + (i == 2 ? 1 : 0),
                    decoration: BoxDecoration(color: Color(state.color), shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
