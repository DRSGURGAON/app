import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/brand.dart';
import '../../app/widgets/brand_mark.dart';
import '../../app/widgets/dialogs.dart';
import '../../app/widgets/states.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_service.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/folder_repository.dart';
import '../../data/services/backup_service.dart';
import '../settings/backup_screen.dart';
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

    final stats = ref.watch(vaultStatsProvider).value;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(
              status: status,
              documentCount: stats?.documentCount,
              onLock: () => ref.read(lockControllerProvider.notifier).lock(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                color: scheme.surfaceContainerLowest,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 6,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuickAction(
                        icon: Icons.document_scanner_outlined,
                        color: const Color(0xFF8C9BFF),
                        label: l.scanDocument,
                        onTap: () => context.push(Routes.scan),
                      ),
                      _QuickAction(
                        key: const Key('home-photos-to-pdf'),
                        icon: Icons.photo_library_outlined,
                        color: const Color(0xFFC792EA),
                        label: l.photosToPdf,
                        onTap: () => context.push(Routes.photosToPdf()),
                      ),
                      _QuickAction(
                        icon: Icons.picture_as_pdf_outlined,
                        color: const Color(0xFFFF8A94),
                        label: l.homeImportPdf,
                        onTap: () =>
                            runImport(context, ref, kind: ImportKind.pdf),
                      ),
                      _QuickAction(
                        icon: Icons.image_outlined,
                        color: const Color(0xFF4FD1B8),
                        label: l.homeImportImage,
                        onTap: () =>
                            runImport(context, ref, kind: ImportKind.image),
                      ),
                      _QuickAction(
                        icon: Icons.create_new_folder_outlined,
                        color: const Color(0xFFF7BE4B),
                        label: l.homeCreateFolder,
                        onTap: () => createFolder(context, ref),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _BackupReminderCard()),
          // Categories first, as folder-like tiles with their icons.
          SliverToBoxAdapter(child: SectionHeader(title: l.homeCategories)),
          SliverToBoxAdapter(
            child: categories.when(
              loading: () => const SizedBox(height: 96),
              error: (e, _) => ErrorState(
                message: errorMessageFor(l, e),
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
              data: (cats) => _CategoryGrid(categories: cats),
            ),
          ),
          SliverToBoxAdapter(child: SectionHeader(title: l.homeExpiringSoon)),
          _PreviewList(
            docs: expiring.whenData((d) => d.take(5).toList()),
            emptyText: l.homeNoExpiring,
          ),
          SliverToBoxAdapter(child: SectionHeader(title: l.homeFavourites)),
          _PreviewList(docs: favourites, emptyText: l.homeNoFavourites),
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
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

/// Navy brand header: logo, lock, search and the security status.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.status,
    required this.documentCount,
    required this.onLock,
  });

  final SecurityStatus? status;
  final int? documentCount;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandMarkSmall(onDark: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.appName,
                          style: text.titleLarge?.copyWith(color: Colors.white),
                        ),
                        if (documentCount != null)
                          Text(
                            l.documentCount(documentCount!),
                            style: text.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.vaultLock,
                    color: Colors.white,
                    icon: const Icon(Icons.lock_outline),
                    onPressed: onLock,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SearchBar(onTap: () => context.push(Routes.search)),
              ),
              if (status != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SecurityPill(status: status!),
                ),
              ],
            ],
          ),
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

IconData categoryIcon(String? key) => CategoryStyle.of(key).icon;

/// Categories as tiles (3 per row on phones, 4 on wider screens). Tiles grow
/// with the text, so long Hindi names and large font sizes never overflow.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories});
  final List<CategorySummary> categories;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final columns = box.maxWidth >= 560 ? 4 : 3;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        // Rows of equal-height tiles (the tallest tile in a row sets it).
        return Column(
          children: [
            for (var i = 0; i < categories.length; i += columns) ...[
              if (i > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + columns; j++) ...[
                      if (j > i) const SizedBox(width: gap),
                      SizedBox(
                        width: width,
                        child: j < categories.length
                            ? _CategoryTile(category: categories[j])
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});
  final CategorySummary category;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = CategoryStyle.of(category.key);
    final name = l.categoryName(category);
    return Card(
      key: Key('home-category-${category.id}'),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.category(category.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                l.documentCount(category.documentCount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewList extends ConsumerWidget {
  const _PreviewList({required this.docs, required this.emptyText});

  final AsyncValue<List<VaultDocument>> docs;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return docs.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox(height: 56)),
      error: (e, _) => SliverToBoxAdapter(
        child: ErrorState(
          message: errorMessageFor(l, e),
          onRetry: () => ref
            ..invalidate(documentsProvider)
            ..invalidate(expiringDocumentsProvider),
        ),
      ),
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
    return Semantics(
      button: true,
      label: l.homeSearchHint,
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.search, color: Brand.inkMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      l.homeSearchHint,
                      style: const TextStyle(color: Brand.inkMuted),
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

/// "Your vault is protected" status on the hero (taps to Privacy & security).
/// Shown when a backup is due (Settings → Backup & restore → reminder).
class _BackupReminderCard extends ConsumerWidget {
  const _BackupReminderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(backupReminderProvider).value;
    if (due == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      key: const Key('backup-reminder-card'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        color: scheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.backupReminderTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          due.lastBackup == null
                              ? l.backupReminderNever
                              : l.backupReminderLast(due.daysSince),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: [
                  TextButton(
                    key: const Key('backup-reminder-later'),
                    onPressed: () async {
                      final service = await ref.read(
                        backupServiceProvider.future,
                      );
                      await service.snoozeReminder();
                      ref.invalidate(backupReminderProvider);
                    },
                    child: Text(l.backupReminderLater),
                  ),
                  FilledButton.tonal(
                    key: const Key('backup-reminder-now'),
                    onPressed: () => context.push(Routes.backup),
                    child: Text(l.backupReminderNow),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityPill extends StatelessWidget {
  const _SecurityPill({required this.status});
  final SecurityStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final weak =
        status.keyProtection == KeyProtection.software ||
        status.keyProtection == KeyProtection.unknown;
    return Material(
      color: Colors.white.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(Routes.privacy),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: weak ? Brand.amber : Brand.teal,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  weak ? Icons.gpp_maybe_outlined : Icons.verified_user,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.homeSecurityTitle,
                      style: text.titleSmall?.copyWith(color: Colors.white),
                    ),
                    Text(
                      status.biometricEnabled
                          ? l.homeSecurityPinBiometric
                          : l.homeSecurityPinOnly,
                      style: text.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}
