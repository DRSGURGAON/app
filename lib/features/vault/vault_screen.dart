import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../core/database/database_opener.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../core/security/security_service.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/document_repository.dart';

/// Phase 1 vault: import (encrypt) and list documents, open a decrypted preview.
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  bool _importing = false;

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);
    try {
      final repo = await ref.read(documentRepositoryProvider.future);
      final outcome = await ref
          .read(lockControllerProvider.notifier)
          .runWithoutAutoLock(repo.importFromPicker);
      if (outcome is ImportSucceeded) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              outcome.isDuplicate ? l.vaultImportedDuplicate : l.vaultImported,
            ),
          ),
        );
      }
    } on SecurityFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorFor(e.code))));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final docs = ref.watch(documentsProvider);
    final status = ref.watch(lockControllerProvider).status;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.vaultTitle),
        actions: [
          IconButton(
            tooltip: l.vaultLock,
            icon: const Icon(Icons.lock_outline),
            onPressed: () => ref.read(lockControllerProvider.notifier).lock(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: _importing
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(Icons.add),
        label: Text(_importing ? l.vaultImporting : l.vaultImport),
      ),
      body: docs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: switch (e) {
            SecurityFailure(:final code) => l.errorFor(code),
            DatabaseKeyMismatch() => l.errorDatabaseKey,
            _ => l.vaultLoadError,
          },
        ),
        data: (items) => CustomScrollView(
          slivers: [
            if (status != null)
              SliverToBoxAdapter(
                child: _ProtectionBanner(protection: status.keyProtection),
              ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(onImport: _importing ? null : _import),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _DocumentTile(doc: items[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProtectionBanner extends StatelessWidget {
  const _ProtectionBanner({required this.protection});
  final KeyProtection protection;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, text, warn) = switch (protection) {
      KeyProtection.strongBox => (
        Icons.verified_user_outlined,
        l.keyProtectionStrongBox,
        false,
      ),
      KeyProtection.trustedEnvironment => (
        Icons.verified_user_outlined,
        l.keyProtectionTee,
        false,
      ),
      KeyProtection.software => (
        Icons.gpp_maybe_outlined,
        l.keyProtectionSoftware,
        true,
      ),
      KeyProtection.unknown => (
        Icons.help_outline,
        l.keyProtectionUnknown,
        true,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: warn ? scheme.error : scheme.primary),
          title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.doc});
  final VaultDocument doc;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final date = DateFormat.yMMMd(locale).format(doc.createdAt);
    final type = doc.isPdf ? l.documentPdf : l.documentImage;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Icon(
            doc.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
          ),
        ),
        title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$type · ${formatBytes(doc.sizeBytes, locale)} · $date'),
        onTap: () => context.push(Routes.preview(doc.id)),
      ),
    );
  }
}

String formatBytes(int bytes, String locale) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var u = 0;
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024;
    u++;
  }
  final f = NumberFormat(u == 0 ? '0' : '0.0', locale);
  return '${f.format(v)} ${units[u]}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(l.vaultEmptyTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            l.vaultEmptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
