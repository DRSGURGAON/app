import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/error_messages.dart';
import '../../../app/localization/gen/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../../core/security/lock_controller.dart';
import '../../../core/security/security_failure.dart';
import '../../../data/models/vault_document.dart';
import '../../../data/repositories/document_repository.dart';

/// Runs the system picker + native encryption and reports the result with a
/// snackbar. The picker puts DocSafe in the background, so auto-lock is
/// suspended for its duration.
Future<void> runImport(
  BuildContext context,
  WidgetRef ref, {
  required ImportKind kind,
  int? folderId,
  int? categoryId,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  try {
    final repo = await ref.read(documentRepositoryProvider.future);
    final outcome = await ref
        .read(lockControllerProvider.notifier)
        .runWithoutAutoLock(
          () => repo.importFromPicker(
            kind: kind,
            folderId: folderId,
            categoryId: categoryId,
          ),
        );
    if (outcome is ImportSucceeded) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            outcome.isDuplicate ? l.vaultImportedDuplicate : l.vaultImported,
          ),
          // Snackbars with actions persist by default; these must time out so
          // they don't block later messages. 8 s leaves time for screen readers.
          persist: false,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: l.importDetailsAction,
            onPressed: () => router.push(Routes.details(outcome.document.id)),
          ),
        ),
      );
    }
  } on SecurityFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l.errorFor(e.code))));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
  }
}

/// Bottom sheet offering PDF or image import.
Future<void> showImportSheet(
  BuildContext context,
  WidgetRef ref, {
  int? folderId,
  int? categoryId,
}) async {
  final l = AppLocalizations.of(context);
  final kind = await showModalBottomSheet<ImportKind>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l.importChooseTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(l.homeImportPdf),
            onTap: () => Navigator.pop(context, ImportKind.pdf),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text(l.homeImportImage),
            onTap: () => Navigator.pop(context, ImportKind.image),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (kind == null || !context.mounted) return;
  await runImport(
    context,
    ref,
    kind: kind,
    folderId: folderId,
    categoryId: categoryId,
  );
}
