import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

/// 밖으로 여는 것을 허용하는 주소인가. 파일·앱 고유 주소(`file:`, `javascript:` 등)는 PDF가 마음대로 열게 하지 않는다.
bool isOpenableLinkUrl(Uri url) => const {'http', 'https', 'mailto'}.contains(url.scheme.toLowerCase());

/// PDF 링크를 누른 것을 처리한다.
/// - 쪽/목적지 링크는 [goToDest]로 이동한다.
/// - 주소 링크는 [confirm]으로 묻고 나서 [launch]로 연다 (둘 다 시험에서 바꿀 수 있다).
Future<void> handlePdfLink(
  BuildContext context,
  PdfLink link, {
  required Future<void> Function(PdfDest dest) goToDest,
  Future<bool> Function(BuildContext context, Uri url)? confirm,
  Future<bool> Function(Uri url)? launch,
}) async {
  final dest = link.dest;
  if (dest != null) {
    await goToDest(dest);
    return;
  }
  final url = link.url;
  if (url == null) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!isOpenableLinkUrl(url)) {
    messenger?.showSnackBar(SnackBar(content: Text(l10n.linkUnsupported)));
    return;
  }
  final ok = await (confirm ?? confirmOpenLink)(context, url);
  if (!ok) return;
  final opened = await (launch ?? _launchExternal)(url);
  if (!opened) messenger?.showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed)));
}

Future<bool> _launchExternal(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// 열기 전에 주소를 보여 주고 확인을 받는다.
Future<bool> confirmOpenLink(BuildContext context, Uri url) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.linkOpenTitle),
      content: SelectableText(l10n.linkOpenBody(url.toString())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
        FilledButton(autofocus: true, onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.linkOpenAction)),
      ],
    ),
  );
  return result ?? false;
}
