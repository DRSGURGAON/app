import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../core/security/security_failure.dart';
import '../../core/security/security_service.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/folder_repository.dart';
import '../../data/repositories/text_rules.dart';
import 'scan_controller.dart';

/// Title, format, category, folder and tags for the scanned pages, then save.
class ScanSaveScreen extends ConsumerStatefulWidget {
  const ScanSaveScreen({super.key, this.folderId, this.categoryId});

  final int? folderId;
  final int? categoryId;

  @override
  ConsumerState<ScanSaveScreen> createState() => _ScanSaveScreenState();
}

class _ScanSaveScreenState extends ConsumerState<ScanSaveScreen> {
  final _title = TextEditingController();
  final _tags = TextEditingController();
  ScanSaveFormat _format = ScanSaveFormat.pdf;
  late int? _folderId = widget.folderId;
  late int? _categoryId = widget.categoryId;
  bool _saving = false;
  String? _error;
  bool _titleInitialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_titleInitialised) {
      _titleInitialised = true;
      final locale = Localizations.localeOf(context).toLanguageTag();
      final stamp = DateFormat.yMMMd(locale).add_Hm().format(DateTime.now());
      _title.text = AppLocalizations.of(context).scanDefaultTitle(stamp);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_title.text.trim().isEmpty) {
      setState(() => _error = l.nameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final docs = await ref
          .read(scanControllerProvider.notifier)
          .save(
            title: _title.text,
            format: _format,
            folderId: _folderId,
            categoryId: _categoryId,
            tags: _tags.text.split(','),
          );
      messenger.showSnackBar(SnackBar(content: Text(l.scanSaved)));
      if (docs.length == 1) {
        router.go(Routes.details(docs.single.id));
      } else {
        router.go(Routes.vault);
      }
    } on SecurityFailure catch (e) {
      // Pages are kept: the user can free space and try again.
      if (mounted) setState(() => _error = l.errorFor(e.code));
    } on ArgumentError {
      if (mounted) setState(() => _error = l.nameRequired);
    } catch (_) {
      if (mounted) setState(() => _error = l.errorGeneric);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pageCount = ref.watch(scanControllerProvider).pages.length;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final folders = ref.watch(foldersProvider).value ?? const [];

    if (_saving) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Semantics(liveRegion: true, child: Text(l.scanSaving)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.scanSaveTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.scanPageCount(pageCount), style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            maxLength: maxTitleLength,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l.detailsTitleLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(l.scanFormatLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<ScanSaveFormat>(
            segments: [
              ButtonSegment(
                value: ScanSaveFormat.pdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(l.scanFormatPdf),
              ),
              ButtonSegment(
                value: ScanSaveFormat.images,
                icon: const Icon(Icons.collections_outlined),
                label: Text(l.scanFormatImages),
              ),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          if (_format == ScanSaveFormat.images && pageCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l.scanFormatImagesNote,
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 20),
          DropdownButtonFormField<int?>(
            isExpanded: true,
            initialValue: _categoryId,
            decoration: InputDecoration(
              labelText: l.detailsCategory,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l.noCategory)),
              for (final c in categories)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    l.categoryName(c),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            isExpanded: true,
            initialValue: _folderId,
            decoration: InputDecoration(
              labelText: l.detailsFolder,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l.noFolder)),
              for (final f in folders)
                DropdownMenuItem(
                  value: f.id,
                  child: Text(f.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _folderId = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tags,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l.scanTagsLabel,
              helperText: l.scanTagsHint,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: pageCount == 0 ? null : _save,
            icon: const Icon(Icons.lock_outline),
            label: Text(l.save),
          ),
        ],
      ),
    );
  }
}
