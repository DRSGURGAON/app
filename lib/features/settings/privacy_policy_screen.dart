import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/states.dart';

/// The privacy policy, shipped with the app (DocSafe has no internet access),
/// in the app's language. Same text as docs/PRIVACY_POLICY.md.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static String assetFor(Locale locale) => locale.languageCode == 'hi'
      ? 'assets/legal/privacy_policy_hi.md'
      : 'assets/legal/privacy_policy_en.md';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asset = assetFor(Localizations.localeOf(context));
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyPolicy)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(asset),
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(message: l.errorGeneric);
          if (!snap.hasData) return const LoadingState();
          final blocks = <Widget>[];
          for (final line in snap.data!.split('\n')) {
            final text = line.trim();
            if (text.isEmpty) continue;
            if (text.startsWith('# ')) {
              blocks.add(
                Text(text.substring(2), style: theme.textTheme.headlineSmall),
              );
            } else if (text.startsWith('## ')) {
              blocks.add(
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    header: true,
                    child: Text(
                      text.substring(3),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              );
            } else if (text.startsWith('- ')) {
              blocks.add(
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: _Rich(text.substring(2))),
                    ],
                  ),
                ),
              );
            } else {
              blocks.add(_Rich(text));
            }
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: blocks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => blocks[i],
          );
        },
      ),
    );
  }
}

/// Paragraph with **bold** spans.
class _Rich extends StatelessWidget {
  const _Rich(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : null,
            ),
        ],
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
