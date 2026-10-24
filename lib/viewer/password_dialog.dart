import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 암호로 보호된 PDF의 암호를 묻는다. 취소하면 null. [wrong]이면 앞서 넣은 암호가 틀렸다는 안내를 보인다.
Future<String?> showPasswordDialog(BuildContext context, {required String fileName, required bool wrong}) =>
    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PasswordDialog(fileName: fileName, wrong: wrong),
    );

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.fileName, required this.wrong});

  final String fileName;
  final bool wrong;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _text = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_text.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.lock_outline_rounded),
      title: Text(l10n.passwordTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.passwordBody(widget.fileName)),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              autofocus: true,
              obscureText: !_visible,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: l10n.passwordHint,
                errorText: widget.wrong ? l10n.passwordWrong : null,
                suffixIcon: IconButton(
                  tooltip: _visible ? l10n.passwordHide : l10n.passwordShow,
                  icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _visible = !_visible),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.passwordOpen)),
      ],
    );
  }
}
