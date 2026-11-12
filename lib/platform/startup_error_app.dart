import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_identity.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 시작에 실패했을 때 띄우는 화면: 창 없이 프로세스만 남는 대신, 무엇이 실패했는지와 기록 파일 위치를 보인다.
/// 설정을 읽지 못했을 수도 있으므로 설정 없이(시스템 언어·테마) 그린다.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, this.logPath});

  final Object error;
  final String? logPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppIdentity.displayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(dense: true),
      darkTheme: AppTheme.dark(dense: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final theme = Theme.of(context);
          final path = logPath ?? '-';
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(l10n.startupFailedTitle, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      SelectableText(l10n.startupFailedBody(path)),
                      const SizedBox(height: 12),
                      SelectableText('$error', style: theme.textTheme.bodySmall),
                      if (logPath != null) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => Clipboard.setData(ClipboardData(text: path)),
                          icon: const Icon(Icons.copy, size: 16),
                          label: Text(MaterialLocalizations.of(context).copyButtonLabel),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
