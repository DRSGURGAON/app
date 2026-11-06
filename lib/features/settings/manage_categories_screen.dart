import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/dialogs.dart';
import '../../app/widgets/states.dart';
import '../../data/repositories/category_repository.dart';
import '../dashboard/home_screen.dart' show categoryIcon;
import '../vault/widgets/document_list.dart';

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cats = ref.watch(categoriesProvider);
    Future<CategoryRepository> repo() =>
        ref.read(categoryRepositoryProvider.future);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsCategories)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.categoriesAdd),
        onPressed: () async {
          final name = await showTextInputDialog(
            context,
            title: l.categoriesAdd,
            label: l.categoryNameLabel,
            confirmLabel: l.create,
          );
          if (name != null) await (await repo()).createCustom(name);
        },
      ),
      body: cats.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: errorMessageFor(l, e)),
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.categoriesDefaultNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final c in list)
              ListTile(
                leading: Icon(categoryIcon(c.key)),
                title: Text(l.categoryName(c)),
                subtitle: Text(l.documentCount(c.documentCount)),
                trailing: c.isDefault
                    ? null
                    : PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'rename') {
                            final n = await showTextInputDialog(
                              context,
                              title: l.rename,
                              label: l.categoryNameLabel,
                              initial: c.customName ?? '',
                              confirmLabel: l.save,
                            );
                            if (n != null) {
                              await (await repo()).renameCustom(c.id, n);
                            }
                          } else {
                            final ok = await showConfirmDialog(
                              context,
                              message: l.categoryDeleteConfirm(
                                l.categoryName(c),
                              ),
                              confirmLabel: l.delete,
                              destructive: true,
                            );
                            if (ok) await (await repo()).deleteCustom(c.id);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'rename', child: Text(l.rename)),
                          PopupMenuItem(value: 'delete', child: Text(l.delete)),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
