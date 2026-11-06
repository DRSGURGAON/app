import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/dialogs.dart';
import '../../app/widgets/states.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/folder_repository.dart';
import 'vault_screen.dart';
import 'widgets/document_list.dart';
import 'widgets/import_flow.dart';

class FolderScreen extends ConsumerWidget {
  const FolderScreen({super.key, required this.folderId});
  final int folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sort = ref.watch(vaultSortProvider);
    final folder = ref
        .watch(foldersProvider)
        .whenData((list) => list.where((f) => f.id == folderId).firstOrNull);
    final docs = ref.watch(
      documentsProvider(DocumentQuery(folderId: folderId, sort: sort)),
    );
    final name = folder.value?.name ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          const SortMenuButton(),
          PopupMenuButton<String>(
            onSelected: (v) async {
              final repo = await ref.read(folderRepositoryProvider.future);
              if (!context.mounted) return;
              if (v == 'rename') {
                final n = await showTextInputDialog(
                  context,
                  title: l.folderRename,
                  label: l.folderNameLabel,
                  initial: name,
                  confirmLabel: l.save,
                );
                if (n != null) await repo.rename(folderId, n);
              } else if (v == 'delete') {
                final ok = await showConfirmDialog(
                  context,
                  title: l.folderDelete,
                  message: l.folderDeleteConfirm(name),
                  confirmLabel: l.delete,
                  destructive: true,
                );
                if (ok) {
                  await repo.delete(folderId);
                  if (context.mounted) context.pop();
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l.folderRename)),
              PopupMenuItem(value: 'delete', child: Text(l.folderDelete)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showImportSheet(context, ref, folderId: folderId),
        icon: const Icon(Icons.add),
        label: Text(l.vaultImport),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          DocumentSliverList(
            docs: docs,
            empty: EmptyState(
              icon: Icons.folder_open_outlined,
              title: l.folderEmpty,
            ),
          ),
        ],
      ),
    );
  }
}
