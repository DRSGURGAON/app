import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/states.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_service.dart';
import '../../data/repositories/document_repository.dart';
import '../vault/widgets/document_list.dart';

final _deviceStorageProvider = FutureProvider.autoDispose<StorageInfo>(
  (ref) => ref.read(securityServiceProvider).getStorageInfo(),
);

class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final stats = ref.watch(vaultStatsProvider);
    final device = ref.watch(_deviceStorageProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsStorage)),
      body: stats.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: errorMessageFor(l, e)),
        data: (s) => ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l.storageDocuments),
              trailing: Text(l.documentCount(s.documentCount)),
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart_outline),
              title: Text(l.storageUsed),
              trailing: Text(formatBytes(s.totalBytes, locale)),
            ),
            ListTile(
              leading: const Icon(Icons.restore_from_trash_outlined),
              title: Text(l.storageInTrash),
              trailing: Text(l.documentCount(s.trashCount)),
            ),
            if (device != null)
              ListTile(
                leading: const Icon(Icons.sd_storage_outlined),
                title: Text(l.storageFree),
                trailing: Text(formatBytes(device.availableBytes, locale)),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.storageNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
