import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/error_messages.dart';
import '../../../app/localization/gen/app_localizations.dart';
import '../../../app/widgets/states.dart';
import '../../../core/database/database_opener.dart';
import '../../../core/security/security_failure.dart';
import '../../../data/models/vault_document.dart';
import 'document_tile.dart';

/// Message for an error coming out of a repository/provider.
String errorMessageFor(AppLocalizations l, Object e) => switch (e) {
  SecurityFailure(:final code) => l.errorFor(code),
  DatabaseKeyMismatch() => l.errorDatabaseKey,
  _ => l.vaultLoadError,
};

/// Sliver list of documents for an AsyncValue, with empty and error states.
class DocumentSliverList extends StatelessWidget {
  const DocumentSliverList({
    super.key,
    required this.docs,
    required this.empty,
  });

  final AsyncValue<List<VaultDocument>> docs;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return docs.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: LoadingState(),
      ),
      error: (e, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorState(message: errorMessageFor(l, e)),
      ),
      data: (items) => items.isEmpty
          ? SliverFillRemaining(hasScrollBody: false, child: empty)
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => DocumentTile(doc: items[i]),
              ),
            ),
    );
  }
}
