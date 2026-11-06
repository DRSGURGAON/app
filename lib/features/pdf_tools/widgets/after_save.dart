import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/gen/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../../data/models/vault_document.dart';

/// Reports and navigates to the result of a PDF tool.
void showToolResult(BuildContext context, List<VaultDocument> docs) {
  if (docs.isEmpty) return;
  final l = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(l.toolDoneCount(docs.length))));
  if (docs.length == 1) {
    context.go(Routes.details(docs.single.id));
  } else {
    context.go(Routes.vault);
  }
}
