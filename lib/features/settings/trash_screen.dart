import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/dialogs.dart';
import '../../app/widgets/states.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/document_repository.dart';
import '../vault/widgets/document_list.dart';
import '../vault/widgets/document_tile.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key, this.now});

  /// Injected for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final trash = ref.watch(trashProvider);
    final count = trash.value?.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.trashTitle),
        actions: [
          if (count > 0)
            TextButton(
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  message: l.trashEmptyConfirm(count),
                  confirmLabel: l.trashEmptyAll,
                  destructive: true,
                );
                if (ok) {
                  await (await ref.read(documentRepositoryProvider.future))
                      .emptyTrash();
                }
              },
              child: Text(l.trashEmptyAll),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                l.trashInfo,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          trash.when(
            loading: () => const SliverFillRemaining(child: LoadingState()),
            error: (e, _) => SliverFillRemaining(
              child: ErrorState(message: errorMessageFor(l, e)),
            ),
            data: (items) => items.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.delete_outline,
                      title: l.trashEmpty,
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _TrashItem(doc: items[i], now: now),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrashItem extends ConsumerWidget {
  const _TrashItem({required this.doc, this.now});
  final VaultDocument doc;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final purgeAt = doc.deletedAt!.add(trashRetention);
    final daysLeft = purgeAt
        .difference(now ?? DateTime.now())
        .inDays
        .clamp(0, trashRetention.inDays);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DocumentTile(
          doc: doc,
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              final repo = await ref.read(documentRepositoryProvider.future);
              if (!context.mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              if (v == 'restore') {
                await repo.restore(doc.id);
                messenger.showSnackBar(
                  SnackBar(content: Text(l.trashRestored)),
                );
              } else {
                final ok = await showConfirmDialog(
                  context,
                  message: l.trashDeleteConfirm(doc.title),
                  confirmLabel: l.trashDeleteForever,
                  destructive: true,
                );
                if (ok) await repo.deletePermanently(doc.id);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'restore', child: Text(l.trashRestore)),
              PopupMenuItem(value: 'delete', child: Text(l.trashDeleteForever)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 4),
          child: Text(
            l.trashDaysLeft(daysLeft),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
