import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 파일을 끌어다 놓는 영역: 점선 테두리, 끌고 들어오면 강조된다 (ui-ux.md §7). [child]는 영역 안 내용이다.
class DropZone extends StatefulWidget {
  const DropZone({
    super.key,
    required this.onDrop,
    required this.child,
    this.radius = AppRadius.card,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  final void Function(List<String> paths) onDrop;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (details) {
        setState(() => _over = false);
        final paths = [for (final f in details.files) f.path];
        if (paths.isNotEmpty) widget.onDrop(paths);
      },
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: _over ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.5),
          radius: widget.radius,
          strokeWidth: _over ? 2 : 1.5,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _over ? scheme.primary.withValues(alpha: 0.08) : scheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius, required this.strokeWidth});

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(strokeWidth / 2));
    const dash = 7.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius || old.strokeWidth != strokeWidth;
}

/// 이미 내용이 있는 화면 위에 얹는 끌어놓기 영역: 점선 틀 없이, 파일을 끌고 들어오면 옅게 물들고 테두리가 생긴다.
class DropArea extends StatefulWidget {
  const DropArea({super.key, required this.onDrop, required this.child});

  final void Function(List<String> paths) onDrop;
  final Widget child;

  @override
  State<DropArea> createState() => _DropAreaState();
}

class _DropAreaState extends State<DropArea> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (details) {
        setState(() => _over = false);
        final paths = [for (final f in details.files) f.path];
        if (paths.isNotEmpty) widget.onDrop(paths);
      },
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: _over ? scheme.primary.withValues(alpha: 0.08) : null,
          border: _over ? Border.all(color: scheme.primary, width: 2) : null,
        ),
        child: widget.child,
      ),
    );
  }
}
