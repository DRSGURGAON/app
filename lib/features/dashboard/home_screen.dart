import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../app/widgets/brand_mark.dart';
import '../../app/widgets/dialogs.dart';
import '../../app/widgets/states.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_service.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/folder_repository.dart';
import '../vault/widgets/document_list.dart';
import '../vault/widgets/document_tile.dart';
import '../vault/widgets/import_flow.dart';

const _recentQuery = DocumentQuery(limit: 5);
const _favouritesQuery = DocumentQuery(favouritesOnly: true, limit: 10);

/// Dashboard: search, security status, quick actions, recent, favourites,
/// categories and expiring documents. Scanning arrives in Phase 3.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final recent = ref.watch(documentsProvider(_recentQuery));
    final favourites = ref.watch(documentsProvider(_favouritesQuery));
    final expiring = ref.watch(expiringDocumentsProvider);
    final categories = ref.watch(categoriesProvider);
    final status = ref.watch(lockControllerProvider).status;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    const ExcludeSemantics(child: BrandMarkSmall()),
                    const SizedBox(width: 12),
                    Text(
                      l.appName,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: l.vaultLock,
                      icon: const Icon(Icons.lock_outline),
                      onPressed: () =>
                          ref.read(lockControllerProvider.notifier).lock(),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SearchBar(onTap: () => context.push(Routes.search)),
              ),
            ),
            if (status != null)
              SliverToBoxAdapter(child: _SecurityCard(status: status)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.document_scanner_outlined,
                        label: l.scanDocument,
                        onTap: () => context.push(Routes.scan),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.picture_as_pdf_outlined,
                        label: l.homeImportPdf,
                        onTap: () =>
                            runImport(context, ref, kind: ImportKind.pdf),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.image_outlined,
                        label: l.homeImportImage,
                        onTap: () =>
                            runImport(context, ref, kind: ImportKind.image),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.create_new_folder_outlined,
                        label: l.homeCreateFolder,
                        onTap: () => createFolder(context, ref),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SectionHeader(title: l.homeExpiringSoon)),
            _PreviewList(
              docs: expiring.whenData((d) => d.take(5).toList()),
              emptyText: l.homeNoExpiring,
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: l.homeRecent,
                trailing: TextButton(
                  onPressed: () => context.go(Routes.vault),
                  child: Text(l.homeSeeAll),
                ),
              ),
            ),
            _PreviewList(docs: recent, emptyText: l.homeNoRecent),
            SliverToBoxAdapter(child: SectionHeader(title: l.homeFavourites)),
            _PreviewList(docs: favourites, emptyText: l.homeNoFavourites),
            SliverToBoxAdapter(child: SectionHeader(title: l.homeCategories)),
            SliverToBoxAdapter(
              child: categories.when(
                loading: () => const SizedBox(height: 48),
                error: (e, _) => ErrorState(message: errorMessageFor(l, e)),
                data: (cats) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in cats)
                        ActionChip(
                          avatar: Icon(categoryIcon(c.key), size: 18),
                          label: Text(
                            c.documentCount == 0
                                ? l.categoryName(c)
                                : '${l.categoryName(c)} · ${c.documentCount}',
                          ),
                          onPressed: () => context.push(Routes.category(c.id)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> createFolder(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final name = await showTextInputDialog(
    context,
    title: l.homeCreateFolder,
    label: l.folderNameLabel,
    confirmLabel: l.create,
  );
  if (name == null) return;
  final repo = await ref.read(folderRepositoryProvider.future);
  final id = await repo.create(name);
  if (context.mounted) await context.push(Routes.folder(id));
}

IconData categoryIcon(String? key) => switch (key) {
  'identity' => Icons.badge_outlined,
  'education' => Icons.school_outlined,
  'vehicle' => Icons.directions_car_outlined,
  'finance' => Icons.account_balance_outlined,
  'insurance' => Icons.health_and_safety_outlined,
  'medical' => Icons.medical_services_outlined,
  'property' => Icons.home_work_outlined,
  'work' => Icons.work_outline,
  'bills' => Icons.receipt_long_outlined,
  'personal' => Icons.person_outline,
  'other' => Icons.category_outlined,
  _ => Icons.label_outline,
};

class _PreviewList extends StatelessWidget {
  const _PreviewList({required this.docs, required this.emptyText});

  final AsyncValue<List<VaultDocument>> docs;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return docs.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox(height: 56)),
      error: (e, _) =>
          SliverToBoxAdapter(child: ErrorState(message: errorMessageFor(l, e))),
      data: (items) => items.isEmpty
          ? SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  emptyText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => DocumentTile(doc: items[i]),
              ),
            ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: l.homeSearchHint,
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.search, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      l.homeSearchHint,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.status});
  final SecurityStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final weak =
        status.keyProtection == KeyProtection.software ||
        status.keyProtection == KeyProtection.unknown;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        color: weak ? null : scheme.primaryContainer.withValues(alpha: .45),
        child: ListTile(
          leading: Icon(
            weak ? Icons.gpp_maybe_outlined : Icons.verified_user_outlined,
            color: weak ? scheme.error : scheme.primary,
          ),
          title: Text(l.homeSecurityTitle),
          subtitle: Text(
            status.biometricEnabled
                ? l.homeSecurityPinBiometric
                : l.homeSecurityPinOnly,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(Routes.privacy),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
