import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/status_pill.dart';

enum NoteDialogAction { save, delete }

/// 메모 창의 결과: 저장(고친 내용 [text]) 또는 삭제. 그냥 닫으면 null.
class NoteDialogResult {
  const NoteDialogResult(this.action, this.text);
  final NoteDialogAction action;
  final String text;
}

/// 메모 내용을 읽고, 고치고, 지우는 창. 내용이 바뀌고 비어 있지 않을 때만 저장할 수 있다.
Future<NoteDialogResult?> showNoteDialog(
  BuildContext context, {
  required String initialText,
  required int pageNumber,
}) => showDialog<NoteDialogResult>(
  context: context,
  builder: (context) => _NoteDialog(initialText: initialText, pageNumber: pageNumber),
);

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initialText, required this.pageNumber});

  final String initialText;
  final int pageNumber;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave {
    final text = _controller.text.trim();
    return text.isNotEmpty && text != widget.initialText.trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.sticky_note_2_outlined, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(l10n.annotNoteTitle),
          const Spacer(),
          StatusPill(label: l10n.pagesPageLabel(widget.pageNumber)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => TextField(
            controller: _controller,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            decoration: InputDecoration(hintText: l10n.annotNoteHint),
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          onPressed: () => Navigator.pop(context, NoteDialogResult(NoteDialogAction.delete, widget.initialText)),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: Text(l10n.annotDelete),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonClose)),
            const SizedBox(width: AppSpacing.sm),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => FilledButton(
                onPressed: _canSave
                    ? () => Navigator.pop(context, NoteDialogResult(NoteDialogAction.save, _controller.text.trim()))
                    : null,
                child: Text(l10n.annotSave),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
