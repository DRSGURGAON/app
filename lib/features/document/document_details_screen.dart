import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../app/widgets/dialogs.dart';
import '../../app/widgets/states.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/folder_repository.dart';
import '../../data/repositories/text_rules.dart';
import '../vault/widgets/document_list.dart';
import '../vault/widgets/document_tile.dart';

class DocumentDetailsScreen extends ConsumerWidget {
  const DocumentDetailsScreen({super.key, required this.documentId});
  final int documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final details = ref.watch(documentDetailsProvider(documentId));
    return details.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(message: errorMessageFor(l, e)),
      ),
      data: (d) => d == null
          ? Scaffold(
              appBar: AppBar(),
              body: EmptyState(
                icon: Icons.search_off,
                title: l.detailsNotFound,
              ),
            )
          : _DetailsView(details: d),
    );
  }
}

class _DetailsView extends ConsumerWidget {
  const _DetailsView({required this.details});
  final DocumentDetails details;

  VaultDocument get doc => details.document;

  Future<DocumentRepository> _repo(WidgetRef ref) =>
      ref.read(documentRepositoryProvider.future);

  Future<void> _guarded(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on SecurityFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorFor(e.code))));
    } on ArgumentError {
      messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final inTrash = doc.deletedAt != null;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final folders = ref.watch(foldersProvider).value ?? const [];
    final category = categories
        .where((c) => c.id == doc.categoryId)
        .firstOrNull;
    final folder = folders.where((f) => f.id == doc.folderId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.detailsTitle),
        actions: [
          if (!inTrash)
            IconButton(
              tooltip: doc.isFavourite
                  ? l.detailsUnfavourite
                  : l.detailsFavourite,
              icon: Icon(
                doc.isFavourite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
              ),
              onPressed: () => _guarded(context, () async {
                await (await _repo(ref)).setFavourite(doc.id, !doc.isFavourite);
              }),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                doc.isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(doc.title, style: theme.textTheme.titleLarge),
            subtitle: Text(
              l.detailsFileInfo(
                l.documentTypeLabel(doc),
                formatBytes(doc.sizeBytes, locale),
                formatDate(doc.createdAt, locale),
              ),
            ),
            trailing: inTrash
                ? null
                : IconButton(
                    tooltip: l.rename,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final t = await showTextInputDialog(
                        context,
                        title: l.rename,
                        label: l.detailsTitleLabel,
                        initial: doc.title,
                        confirmLabel: l.save,
                        maxLength: maxTitleLength,
                      );
                      if (t == null || !context.mounted) return;
                      await _guarded(
                        context,
                        () async => (await _repo(ref)).rename(doc.id, t),
                      );
                    },
                  ),
          ),
          if (!inTrash)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(Routes.viewer(doc.id)),
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text(l.detailsOpen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _export(context, ref),
                      icon: const Icon(Icons.ios_share_outlined),
                      label: Text(l.detailsExport),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l.detailsCategory),
            subtitle: Text(
              category == null ? l.noCategory : l.categoryName(category),
            ),
            enabled: !inTrash,
            onTap: () async {
              final picked = await _pick<int?>(
                context,
                title: l.detailsCategory,
                current: doc.categoryId,
                options: [
                  (null, l.noCategory),
                  for (final c in categories) (c.id, l.categoryName(c)),
                ],
              );
              if (picked == null || !context.mounted) return;
              await _guarded(
                context,
                () async => (await _repo(ref)).setCategory(doc.id, picked.$1),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(l.detailsFolder),
            subtitle: Text(folder?.name ?? l.noFolder),
            enabled: !inTrash,
            onTap: () async {
              final picked = await _pick<int?>(
                context,
                title: l.detailsFolder,
                current: doc.folderId,
                options: [
                  (null, l.noFolder),
                  for (final f in folders) (f.id, f.name),
                ],
              );
              if (picked == null || !context.mounted) return;
              await _guarded(
                context,
                () async => (await _repo(ref)).moveToFolder(doc.id, picked.$1),
              );
            },
          ),
          _TagsTile(details: details, enabled: !inTrash),
          _DateTile(
            icon: Icons.event_available_outlined,
            label: l.detailsIssueDate,
            value: details.issueDate,
            enabled: !inTrash,
            onChanged: (v) =>
                _saveDates(context, ref, issue: v, expiry: details.expiryDate),
          ),
          _DateTile(
            icon: Icons.event_outlined,
            label: l.detailsExpiryDate,
            value: details.expiryDate,
            enabled: !inTrash,
            badge: details.expiryDate == null
                ? null
                : ExpiryBadge(isoDate: details.expiryDate!),
            onChanged: (v) =>
                _saveDates(context, ref, issue: details.issueDate, expiry: v),
          ),
          ListTile(
            leading: const Icon(Icons.notes_outlined),
            title: Text(l.detailsNotes),
            subtitle: Text(
              details.notes ?? l.detailsNotSet,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            enabled: !inTrash,
            onTap: () async {
              final n = await showTextInputDialog(
                context,
                title: l.detailsNotes,
                label: l.detailsNotes,
                initial: details.notes ?? '',
                confirmLabel: l.save,
                maxLength: 2000,
                maxLines: 6,
                helper: l.detailsNotesHint,
              );
              if (n == null || !context.mounted) return;
              await _guarded(
                context,
                () async => (await _repo(ref)).saveMetadata(
                  doc.id,
                  issueDate: details.issueDate,
                  expiryDate: details.expiryDate,
                  notes: n,
                ),
              );
            },
          ),
          const Divider(height: 24),
          if (!inTrash)
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                l.detailsDelete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () => _delete(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _saveDates(
    BuildContext context,
    WidgetRef ref, {
    required String? issue,
    required String? expiry,
  }) async {
    final l = AppLocalizations.of(context);
    if (issue != null && expiry != null && expiry.compareTo(issue) < 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.detailsExpiryBeforeIssue)));
      return;
    }
    await _guarded(
      context,
      () async => (await _repo(ref)).saveMetadata(
        doc.id,
        issueDate: issue,
        expiryDate: expiry,
        notes: details.notes,
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l.exportWarningTitle,
      message: l.exportWarningBody,
      confirmLabel: l.exportContinue,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await _guarded(context, () async {
      final repo = await _repo(ref);
      final done = await ref
          .read(lockControllerProvider.notifier)
          .runWithoutAutoLock(() => repo.export(doc));
      if (done) messenger.showSnackBar(SnackBar(content: Text(l.exportDone)));
    });
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = await _repo(ref);
    await repo.moveToTrash(doc.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.detailsMovedToTrash),
        // Snackbars with actions persist by default; these must time out so
        // they don't block later messages. 8 s leaves time for screen readers.
        persist: false,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => repo.restore(doc.id),
        ),
      ),
    );
    if (context.mounted) context.pop();
  }
}

/// Single-choice bottom sheet. Returns a record so "null" can be a real choice.
Future<(T,)?> _pick<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<(T, String)> options,
}) {
  return showModalBottomSheet<(T,)>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final (value, label) in options)
              ListTile(
                title: Text(label),
                trailing: value == current ? const Icon(Icons.check) : null,
                selected: value == current,
                onTap: () => Navigator.pop(context, (value,)),
              ),
          ],
        ),
      ),
    ),
  );
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool enabled;
  final Widget? badge;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: value == null
          ? Text(l.detailsNotSet)
          : badge ?? Text(formatIsoDate(value!, locale)),
      enabled: enabled,
      trailing: value == null || !enabled
          ? null
          : IconButton(
              tooltip: l.clearValue,
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value == null ? now : parseIsoDate(value!),
          firstDate: DateTime(1950),
          lastDate: DateTime(now.year + 50),
        );
        if (picked != null) onChanged(isoDate(picked));
      },
    );
  }
}

class _TagsTile extends ConsumerWidget {
  const _TagsTile({required this.details, required this.enabled});
  final DocumentDetails details;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final tags = details.tags;
    Future<void> save(List<String> next) async {
      final repo = await ref.read(documentRepositoryProvider.future);
      await repo.setTags(details.document.id, next);
    }

    return ListTile(
      leading: const Icon(Icons.sell_outlined),
      title: Text(l.detailsTags),
      enabled: enabled,
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in tags)
              InputChip(
                label: Text(t),
                onDeleted: enabled ? () => save([...tags]..remove(t)) : null,
                deleteButtonTooltipMessage: l.delete,
              ),
            if (enabled && tags.length < maxTagsPerDocument)
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(l.detailsAddTag),
                onPressed: () async {
                  final t = await showTextInputDialog(
                    context,
                    title: l.detailsAddTag,
                    label: l.detailsTagLabel,
                    confirmLabel: l.add,
                    maxLength: maxTagLength,
                  );
                  if (t != null) await save([...tags, t]);
                },
              ),
          ],
        ),
      ),
    );
  }
}
