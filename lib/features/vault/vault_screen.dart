import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../app/widgets/states.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/folder_repository.dart';
import '../dashboard/home_screen.dart' show createFolder;
import 'widgets/document_list.dart';
import 'widgets/import_flow.dart';

/// Sort order and favourites filter shared by vault, folder and category views.
final vaultSortProvider = NotifierProvider<VaultSortController, DocumentSort>(
  VaultSortController.new,
);

class VaultSortController extends Notifier<DocumentSort> {
  @override
  DocumentSort build() => DocumentSort.newest;

  void set(DocumentSort s) => state = s;
}

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  bool _favouritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sort = ref.watch(vaultSortProvider);
    final query = DocumentQuery(sort: sort, favouritesOnly: _favouritesOnly);
    final docs = ref.watch(documentsProvider(query));
    final folders = ref.watch(foldersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.vaultTitle),
        actions: [
          IconButton(
            tooltip: l.homeSearchHint,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
          const SortMenuButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showImportSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.vaultImport),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SectionHeader(
              title: l.vaultFolders,
              trailing: IconButton(
                tooltip: l.homeCreateFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: () => createFolder(context, ref),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: folders.when(
              loading: () => const SizedBox(height: 56),
              error: (e, _) => ErrorState(message: errorMessageFor(l, e)),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        l.vaultNoFolders,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : SizedBox(
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => _FolderCard(folder: list[i]),
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: l.vaultAllDocuments,
              trailing: FilterChip(
                label: Text(l.filterFavourites),
                selected: _favouritesOnly,
                onSelected: (v) => setState(() => _favouritesOnly = v),
              ),
            ),
          ),
          DocumentSliverList(
            docs: docs,
            empty: EmptyState(
              icon: Icons.folder_open_outlined,
              title: l.vaultEmptyTitle,
              body: l.vaultEmptyBody,
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.folder});
  final FolderSummary folder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 148,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(Routes.folder(folder.id)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_rounded, color: scheme.primary),
                const SizedBox(height: 4),
                Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  l.documentCount(folder.documentCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SortMenuButton extends ConsumerWidget {
  const SortMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = ref.watch(vaultSortProvider);
    return PopupMenuButton<DocumentSort>(
      tooltip: l.sortLabel,
      icon: const Icon(Icons.sort),
      initialValue: current,
      onSelected: (s) => ref.read(vaultSortProvider.notifier).set(s),
      itemBuilder: (_) => [
        for (final s in DocumentSort.values)
          CheckedPopupMenuItem(
            value: s,
            checked: s == current,
            child: Text(l.sortLabelFor(s)),
          ),
      ],
    );
  }
}
