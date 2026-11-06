import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/localization/error_messages.dart';
import '../../../app/localization/gen/app_localizations.dart';
import '../../../core/security/security_failure.dart';

/// Runs a PDF operation behind a blocking progress dialog. Returns null (after
/// showing a message) if it failed.
Future<T?> runTool<T>(BuildContext context, Future<T> Function() op) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Semantics(liveRegion: true, child: Text(l.toolWorking)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await op();
  } on SecurityFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l.errorFor(e.code))));
  } on ArgumentError {
    messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
  } finally {
    if (navigator.canPop()) navigator.pop();
  }
  return null;
}
