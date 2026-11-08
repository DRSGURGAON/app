import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/display_names.dart';
import '../../../app/localization/gen/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/brand.dart';
import '../../../data/models/vault_document.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/text_rules.dart';

class DocumentTile extends ConsumerWidget {
  const DocumentTile({super.key, required this.doc, this.today, this.trailing});

  final VaultDocument doc;

  /// Injected for tests; defaults to the current date.
  final DateTime? today;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final category = categories
        .where((c) => c.id == doc.categoryId)
        .firstOrNull;
    final style = category == null
        ? CategoryStyle(
            scheme.primary,
            doc.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
          )
        : CategoryStyle.of(category.key);
    final subtitle = [
      if (category != null) l.categoryName(category),
      l.documentTypeLabel(doc),
      formatBytes(doc.sizeBytes, locale),
    ].join(' · ');
    return Card(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.details(doc.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(style.icon, color: style.color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            doc.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (doc.isFavourite) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Brand.gold,
                            semanticLabel: l.homeFavourites,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (doc.expiryDate != null) ...[
                      const SizedBox(height: 6),
                      ExpiryBadge(isoDate: doc.expiryDate!, today: today),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
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
    final (fg, bg) = expired
        ? (scheme.error, scheme.errorContainer)
        : soon
        ? (scheme.tertiary, scheme.tertiaryContainer)
        : (scheme.onSurfaceVariant, scheme.surfaceContainerHigh);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expired ? Icons.event_busy_outlined : Icons.event_outlined,
              size: 14,
              color: fg,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                expired ? l.expiredOn(date) : l.expiresOn(date),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: fg, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String isoDateOf(DateTime d) => isoDate(d);
