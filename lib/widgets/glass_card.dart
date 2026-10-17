import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Saturn 카드: 면 색 + 1px 테두리 (유리 효과는 BackdropFilter 없이 흉내 낸다, ui-ux.md §3).
/// [selected]면 강조색 테두리와 옅은 강조 배경, [onTap]이 있으면 눌림 효과가 붙는다.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.card,
    this.selected = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
    );
    return Material(
      color: selected ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), scheme.surface) : scheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}
