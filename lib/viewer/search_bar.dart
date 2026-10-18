import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// PDF 안 글자 찾기 줄: 입력하면 찾고, Enter/Shift+Enter(또는 단추)로 결과 사이를 옮기고, Esc로 닫는다.
class ViewerSearchBar extends StatefulWidget {
  const ViewerSearchBar({super.key, required this.searcher, required this.onClose});

  final PdfTextSearcher searcher;
  final VoidCallback onClose;

  @override
  State<ViewerSearchBar> createState() => _ViewerSearchBarState();
}

class _ViewerSearchBarState extends State<ViewerSearchBar> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  /// 결과 사이를 옮긴다. pdfrx는 옮긴 뒤에 듣는 쪽에 알리지 않으므로 "3 / 12" 표시는 우리가 다시 그린다.
  Future<void> _go({required bool next}) async {
    await (next ? widget.searcher.goToNextMatch() : widget.searcher.goToPrevMatch());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
        const SingleActivator(LogicalKeyboardKey.enter, shift: true): () => _go(next: false),
      },
      child: ListenableBuilder(
        listenable: widget.searcher,
        builder: (context, _) {
          final s = widget.searcher;
          final typed = _text.text.isNotEmpty;
          final status = s.isSearching && s.matches.isEmpty
              ? l10n.searchSearching
              : s.hasMatches
              ? l10n.searchCount(s.currentIndex! + 1, s.matches.length)
              : typed && !s.isSearching
              ? l10n.searchNoResults
              : '';
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        decoration: InputDecoration(isDense: true, hintText: l10n.searchHint, border: InputBorder.none),
                        onChanged: (v) {
                          setState(() {});
                          s.startTextSearch(v);
                        },
                        onSubmitted: (_) {
                          _go(next: true);
                          _focus.requestFocus();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 96,
                      child: Text(
                        status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: status == l10n.searchNoResults ? theme.colorScheme.error : null,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.searchPrev,
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      onPressed: s.hasMatches ? () => _go(next: false) : null,
                    ),
                    IconButton(
                      tooltip: l10n.searchNext,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: s.hasMatches ? () => _go(next: true) : null,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: l10n.searchClose,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              if (s.isSearching) const LinearProgressIndicator(minHeight: 2),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }
}
