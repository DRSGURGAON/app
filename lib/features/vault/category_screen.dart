import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/states.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../dashboard/home_screen.dart' show categoryIcon;
import 'vault_screen.dart';
import 'widgets/document_list.dart';
import 'widgets/import_flow.dart';

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.categoryId});
  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sort = ref.watch(vaultSortProvider);
    final category = ref
        .watch(categoriesProvider)
        .value
        ?.where((c) => c.id == categoryId)
        .firstOrNull;
    final docs = ref.watch(
      documentsProvider(DocumentQuery(categoryId: categoryId, sort: sort)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(category == null ? '' : l.categoryName(category)),
        actions: const [SortMenuButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showImportSheet(context, ref, categoryId: categoryId),
        icon: const Icon(Icons.add),
        label: Text(l.vaultImport),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          DocumentSliverList(
            docs: docs,
            empty: EmptyState(
              icon: categoryIcon(category?.key),
              title: l.categoryEmpty,
            ),
          ),
        ],
      ),
    );
  }
}
