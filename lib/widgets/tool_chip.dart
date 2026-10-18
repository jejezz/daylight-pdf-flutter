import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 아이콘 + 글자 도구 버튼. 도구 줄에서 아이콘만 늘어놓지 않고 이름을 함께 보여 준다.
/// [selected]면 강조 배경, [label]을 숨기면(`compact`) 아이콘만 남고 [tooltip]은 항상 붙는다.
class ToolChip extends StatelessWidget {
  const ToolChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.selected = false,
    this.compact = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;
  final bool compact;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final color = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : danger
        ? scheme.error
        : selected
        ? scheme.primary
        : scheme.onSurface;
    return Tooltip(
      message: tooltip ?? label,
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? AppSpacing.sm : AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
