import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme/app_theme.dart';

/// PDF 목차(북마크) 트리. 제목을 누르면 [onTap]으로 그 자리로 옮긴다. 하위 항목이 있으면 펼침 단추가 붙는다.
class OutlinePanel extends StatefulWidget {
  const OutlinePanel({super.key, required this.nodes, required this.onTap});

  final List<PdfOutlineNode> nodes;
  final void Function(PdfOutlineNode node) onTap;

  @override
  State<OutlinePanel> createState() => _OutlinePanelState();
}

class _OutlinePanelState extends State<OutlinePanel> {
  /// 펼쳐진 항목 (노드 객체 기준). 첫 단계는 처음에 펼쳐 둔다.
  late final Set<PdfOutlineNode> _expanded = {...widget.nodes};

  void _flatten(List<PdfOutlineNode> nodes, int depth, List<(PdfOutlineNode, int)> out) {
    for (final n in nodes) {
      out.add((n, depth));
      if (_expanded.contains(n)) _flatten(n.children, depth + 1, out);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(PdfOutlineNode, int)>[];
    _flatten(widget.nodes, 0, rows);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (node, depth) = rows[i];
        final hasChildren = node.children.isNotEmpty;
        final open = _expanded.contains(node);
        return InkWell(
          onTap: () => widget.onTap(node),
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xs + depth * 14.0, 2, AppSpacing.sm, 2),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: hasChildren
                      ? InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => open ? _expanded.remove(node) : _expanded.add(node)),
                          child: Icon(open ? Icons.expand_more_rounded : Icons.chevron_right_rounded, size: 18),
                        )
                      : null,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      node.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: depth == 0 ? FontWeight.w700 : null),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
