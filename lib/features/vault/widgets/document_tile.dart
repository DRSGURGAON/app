import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/display_names.dart';
import '../../../app/localization/gen/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../../data/models/vault_document.dart';
import '../../../data/repositories/text_rules.dart';

class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.doc, this.today, this.trailing});

  final VaultDocument doc;

  /// Injected for tests; defaults to the current date.
  final DateTime? today;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final subtitle =
        '${l.documentTypeLabel(doc)} · ${formatBytes(doc.sizeBytes, locale)} · '
        '${formatDate(doc.createdAt, locale)}';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Icon(
            doc.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                doc.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (doc.isFavourite) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.star_rounded,
                size: 18,
                color: scheme.tertiary,
                semanticLabel: l.homeFavourites,
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (doc.expiryDate != null)
              ExpiryBadge(isoDate: doc.expiryDate!, today: today),
          ],
        ),
        trailing: trailing,
        onTap: () => context.push(Routes.details(doc.id)),
      ),
    );
  }
}

/// "Expires 12 Mar 2027" / "Expired …", coloured when within 30 days.
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.isoDate, this.today});

  final String isoDate;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final now = today ?? DateTime.now();
    final todayIso = isoDateOf(now);
    final soonIso = isoDateOf(now.add(const Duration(days: 30)));
    final expired = isoDate.compareTo(todayIso) < 0;
    final soon = !expired && isoDate.compareTo(soonIso) <= 0;
    final date = formatIsoDate(isoDate, locale);
    final color = expired
        ? scheme.error
        : soon
        ? scheme.tertiary
        : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            expired ? Icons.event_busy_outlined : Icons.event_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              expired ? l.expiredOn(date) : l.expiresOn(date),
              style: TextStyle(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

String isoDateOf(DateTime d) => isoDate(d);
