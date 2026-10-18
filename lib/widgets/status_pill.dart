import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum PillTone { neutral, info, success, warning, danger }

/// 상태 알약: 옅은 색 배경 + 같은 계열 글자. 라이트에서는 대비가 모자란 색을 글자용 변형으로 바꾼다 (theming.md §2).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = PillTone.neutral, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final color = switch (tone) {
      PillTone.neutral => theme.colorScheme.onSurface,
      PillTone.info => theme.colorScheme.primary,
      PillTone.success => light ? AppColors.successTextLight : AppColors.success,
      PillTone.warning => light ? AppColors.warningTextLight : AppColors.warning,
      PillTone.danger => light ? AppColors.dangerTextLight : AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - 2, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
