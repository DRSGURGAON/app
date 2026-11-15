import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/display_names.dart';
import '../../../app/localization/gen/app_localizations.dart';
import '../../../core/entitlement/entitlement.dart';
import '../../../data/models/vault_document.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/document_repository.dart';
import '../../../data/repositories/text_rules.dart';
import '../../premium/premium_screen.dart';

/// Filters only apply with Premium: without it a screen queries unfiltered.
DocumentFilters effectiveFilters(WidgetRef ref, DocumentFilters f) =>
    ref.watch(premiumUnlockedProvider) ? f : const DocumentFilters();

/// App bar button: opens the filter sheet (Premium) and reports the result.
class FilterButton extends ConsumerWidget {
  const FilterButton({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  final DocumentFilters filters;
  final ValueChanged<DocumentFilters> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final premium = ref.watch(premiumUnlockedProvider);
    final count = premium ? filters.activeCount : 0;
    return IconButton(
      key: const Key('filter-button'),
      tooltip: count == 0 ? l.filterTitle : l.filterActive(count),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: Icon(premium ? Icons.tune : Icons.tune_outlined),
      ),
      onPressed: () async {
        if (!ref.read(premiumUnlockedProvider)) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PremiumScreen(feature: l.premiumFilters),
            ),
          );
          if (!context.mounted || !ref.read(premiumUnlockedProvider)) return;
        }
        final picked = await showFilterSheet(context, filters);
        if (picked != null) onChanged(picked);
      },
    );
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

Future<DocumentFilters?> showFilterSheet(
  BuildContext context,
  DocumentFilters current,
) => showModalBottomSheet<DocumentFilters>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _FilterSheet(initial: current),
);

enum _AddedPreset { any, last7, last30, year, custom }

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});
  final DocumentFilters initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late DocumentFilters f = widget.initial;

  _AddedPreset get _preset {
    if (f.addedFrom == null && f.addedTo == null) return _AddedPreset.any;
    final today = _day(DateTime.now());
    if (f.addedTo == null && f.addedFrom != null) {
      if (f.addedFrom == today.subtract(const Duration(days: 6))) {
        return _AddedPreset.last7;
      }
      if (f.addedFrom == today.subtract(const Duration(days: 29))) {
        return _AddedPreset.last30;
      }
      if (f.addedFrom == DateTime(today.year)) return _AddedPreset.year;
    }
    return _AddedPreset.custom;
  }

  DocumentFilters _with({
    TypeFilter? type,
    ExpiryFilter? expiry,
    (DateTime?, DateTime?)? added,
    (int?,)? category,
    (String?,)? tag,
  }) => DocumentFilters(
    type: type ?? f.type,
    expiry: expiry ?? f.expiry,
    addedFrom: added == null ? f.addedFrom : added.$1,
    addedTo: added == null ? f.addedTo : added.$2,
    categoryId: category == null ? f.categoryId : category.$1,
    tag: tag == null ? f.tag : tag.$1,
  );

  Future<void> _pickAdded(_AddedPreset p) async {
    final today = _day(DateTime.now());
    switch (p) {
      case _AddedPreset.any:
        setState(() => f = _with(added: (null, null)));
      case _AddedPreset.last7:
        setState(
          () =>
              f = _with(added: (today.subtract(const Duration(days: 6)), null)),
        );
      case _AddedPreset.last30:
        setState(
          () => f = _with(
            added: (today.subtract(const Duration(days: 29)), null),
          ),
        );
      case _AddedPreset.year:
        setState(() => f = _with(added: (DateTime(today.year), null)));
      case _AddedPreset.custom:
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: today,
          initialDateRange: f.addedFrom != null && f.addedTo != null
              ? DateTimeRange(start: f.addedFrom!, end: f.addedTo!)
              : null,
        );
        if (range != null && mounted) {
          setState(
            () => f = _with(added: (_day(range.start), _day(range.end))),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final tags = ref.watch(allTagsProvider).value ?? const [];
    final preset = _preset;

    Widget section(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );

    Widget choice<T>(String label, T value, T current, VoidCallback onTap) =>
        ChoiceChip(
          label: Text(label),
          selected: value == current,
          onSelected: (_) => onTap(),
        );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.filterTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    key: const Key('filter-clear'),
                    onPressed: f.isEmpty
                        ? null
                        : () => setState(() => f = const DocumentFilters()),
                    child: Text(l.filterClearAll),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  section(l.filterType, [
                    for (final (t, label) in [
                      (TypeFilter.any, l.filterTypeAll),
                      (TypeFilter.pdf, l.filterTypePdf),
                      (TypeFilter.image, l.filterTypeImage),
                    ])
                      choice(
                        label,
                        t,
                        f.type,
                        () => setState(() => f = _with(type: t)),
                      ),
                  ]),
                  section(l.filterExpiry, [
                    for (final (e, label) in [
                      (ExpiryFilter.any, l.filterAny),
                      (ExpiryFilter.expired, l.filterExpiryExpired),
                      (ExpiryFilter.within30Days, l.filterExpirySoon),
                      (ExpiryFilter.hasExpiry, l.filterExpiryHas),
                      (ExpiryFilter.noExpiry, l.filterExpiryNone),
                    ])
                      choice(
                        label,
                        e,
                        f.expiry,
                        () => setState(() => f = _with(expiry: e)),
                      ),
                  ]),
                  section(l.filterAdded, [
                    for (final (p, label) in [
                      (_AddedPreset.any, l.filterAddedAny),
                      (_AddedPreset.last7, l.filterAdded7),
                      (_AddedPreset.last30, l.filterAdded30),
                      (_AddedPreset.year, l.filterAddedYear),
                      (
                        _AddedPreset.custom,
                        preset == _AddedPreset.custom
                            ? addedLabel(l, f, locale)!
                            : l.filterAddedCustom,
                      ),
                    ])
                      choice(label, p, preset, () => _pickAdded(p)),
                  ]),
                  section(l.detailsCategory, [
                    choice(
                      l.filterAny,
                      null,
                      f.categoryId,
                      () => setState(() => f = _with(category: (null,))),
                    ),
                    for (final c in categories)
                      choice(
                        l.categoryName(c),
                        c.id,
                        f.categoryId,
                        () => setState(() => f = _with(category: (c.id,))),
                      ),
                  ]),
                  section(l.filterTag, [
                    if (tags.isEmpty)
                      Text(l.filterNoTags, style: theme.textTheme.bodySmall)
                    else ...[
                      choice(
                        l.filterAny,
                        null,
                        f.tag?.toLowerCase(),
                        () => setState(() => f = _with(tag: (null,))),
                      ),
                      for (final t in tags)
                        choice(
                          t,
                          t.toLowerCase(),
                          f.tag?.toLowerCase(),
                          () => setState(() => f = _with(tag: (t,))),
                        ),
                    ],
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('filter-apply'),
                  onPressed: () => Navigator.pop(context, f),
                  child: Text(l.filterApply),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "12 Mar 2026 – 20 Mar 2026", "Since …", "Until …" or null.
String? addedLabel(AppLocalizations l, DocumentFilters f, String locale) {
  String fmt(DateTime d) => formatIsoDate(isoDate(d), locale);
  return switch ((f.addedFrom, f.addedTo)) {
    (null, null) => null,
    (final a?, null) => l.filterAddedSince(fmt(a)),
    (null, final b?) => l.filterAddedUntil(fmt(b)),
    (final a?, final b?) => l.filterAddedRange(fmt(a), fmt(b)),
  };
}

/// Removable chips for the active filters, shown above a filtered list.
class ActiveFilterChips extends ConsumerWidget {
  const ActiveFilterChips({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  final DocumentFilters filters;
  final ValueChanged<DocumentFilters> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(premiumUnlockedProvider) || filters.isEmpty) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final f = filters;
    DocumentFilters without({
      bool type = false,
      bool expiry = false,
      bool added = false,
      bool category = false,
      bool tag = false,
    }) => DocumentFilters(
      type: type ? TypeFilter.any : f.type,
      expiry: expiry ? ExpiryFilter.any : f.expiry,
      addedFrom: added ? null : f.addedFrom,
      addedTo: added ? null : f.addedTo,
      categoryId: category ? null : f.categoryId,
      tag: tag ? null : f.tag,
    );
    final category = categories.where((c) => c.id == f.categoryId).firstOrNull;
    final chips = <(String, DocumentFilters)>[
      if (f.type != TypeFilter.any)
        (
          f.type == TypeFilter.pdf ? l.filterTypePdf : l.filterTypeImage,
          without(type: true),
        ),
      if (f.expiry != ExpiryFilter.any)
        (
          switch (f.expiry) {
            ExpiryFilter.expired => l.filterExpiryExpired,
            ExpiryFilter.within30Days => l.filterExpirySoon,
            ExpiryFilter.hasExpiry => l.filterExpiryHas,
            _ => l.filterExpiryNone,
          },
          without(expiry: true),
        ),
      if (addedLabel(l, f, locale) case final a?) (a, without(added: true)),
      if (f.categoryId != null && category != null)
        (l.categoryName(category), without(category: true)),
      if (f.tag case final t?) (l.filterTagValue(t), without(tag: true)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (label, next) in chips)
            InputChip(label: Text(label), onDeleted: () => onChanged(next)),
          TextButton(
            key: const Key('filter-chips-clear'),
            onPressed: () => onChanged(const DocumentFilters()),
            child: Text(l.filterClearAll),
          ),
        ],
      ),
    );
  }
}
