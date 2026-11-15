import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/display_names.dart';
import '../../../app/localization/error_messages.dart';
import '../../../app/localization/gen/app_localizations.dart';
import '../../../app/widgets/dialogs.dart';
import '../../../core/entitlement/entitlement.dart';
import '../../../core/security/lock_controller.dart';
import '../../../core/security/security_failure.dart';
import '../../../data/models/vault_document.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/document_repository.dart';
import '../../../data/repositories/folder_repository.dart';
import '../../../data/repositories/text_rules.dart';
import '../../premium/premium_screen.dart';

/// Which documents are selected on one screen (batch actions, Premium).
class DocumentSelection extends ChangeNotifier {
  final Set<int> _ids = {};
  List<VaultDocument> _visible = const [];
  bool _active = false;

  bool get active => _active;
  int get count => _ids.length;
  bool contains(int id) => _ids.contains(id);

  /// Selected documents among those currently listed, in list order.
  List<VaultDocument> get documents => [
    for (final d in _visible)
      if (_ids.contains(d.id)) d,
  ];

  bool get allSelected =>
      _visible.isNotEmpty && _visible.every((d) => _ids.contains(d.id));

  /// Called by the list on every rebuild. Drops selected documents that are
  /// no longer listed (deleted, moved out of a folder, filtered away).
  void updateVisible(List<VaultDocument> docs) {
    _visible = docs;
    final listed = {for (final d in docs) d.id};
    final before = _ids.length;
    _ids.retainWhere(listed.contains);
    if (_ids.length != before) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  void start([int? id]) {
    _active = true;
    if (id != null) _ids.add(id);
    notifyListeners();
  }

  void toggle(int id) {
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
  }

  void toggleAll() {
    if (allSelected) {
      _ids.clear();
    } else {
      _ids.addAll(_visible.map((d) => d.id));
    }
    notifyListeners();
  }

  void end() {
    _active = false;
    _ids.clear();
    notifyListeners();
  }
}

class SelectionScope extends InheritedNotifier<DocumentSelection> {
  const SelectionScope({
    super.key,
    required DocumentSelection selection,
    required super.child,
  }) : super(notifier: selection);

  static DocumentSelection? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SelectionScope>()?.notifier;
}

/// Starts selection mode if the user has Premium (else shows Premium first).
Future<void> startSelection(
  BuildContext context,
  WidgetRef ref,
  DocumentSelection selection, [
  int? id,
]) async {
  if (!ref.read(premiumUnlockedProvider)) {
    final l = AppLocalizations.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PremiumScreen(feature: l.premiumBatch),
      ),
    );
    if (!context.mounted || !ref.read(premiumUnlockedProvider)) return;
  }
  unawaited(HapticFeedback.selectionClick());
  selection.start(id);
}

/// A Scaffold whose app bar and bottom bar switch to batch actions while
/// documents are selected. Back leaves selection mode first.
class SelectableScaffold extends StatefulWidget {
  const SelectableScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.floatingActionButton,
  });

  final PreferredSizeWidget appBar;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  State<SelectableScaffold> createState() => _SelectableScaffoldState();
}

class _SelectableScaffoldState extends State<SelectableScaffold> {
  final _selection = DocumentSelection();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionScope(
    selection: _selection,
    child: ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        final active = _selection.active;
        return PopScope(
          canPop: !active,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _selection.end();
          },
          child: Scaffold(
            appBar: active ? _SelectionAppBar(_selection) : widget.appBar,
            body: widget.body,
            floatingActionButton: active ? null : widget.floatingActionButton,
            bottomNavigationBar: active ? _BatchBar(_selection) : null,
          ),
        );
      },
    ),
  );
}

/// App bar action that enters selection mode.
class SelectButton extends ConsumerWidget {
  const SelectButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selection = SelectionScope.maybeOf(context);
    if (selection == null) return const SizedBox.shrink();
    return IconButton(
      key: const Key('select-button'),
      tooltip: l.selectDocuments,
      icon: const Icon(Icons.checklist_rounded),
      onPressed: () => startSelection(context, ref, selection),
    );
  }
}

class _SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SelectionAppBar(this.selection);
  final DocumentSelection selection;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        key: const Key('selection-close'),
        tooltip: l.selectionCancel,
        icon: const Icon(Icons.close),
        onPressed: selection.end,
      ),
      title: Semantics(
        liveRegion: true,
        child: Text(l.selectionCount(selection.count)),
      ),
      actions: [
        IconButton(
          key: const Key('select-all'),
          tooltip: l.selectAll,
          isSelected: selection.allSelected,
          icon: const Icon(Icons.select_all),
          onPressed: selection.toggleAll,
        ),
      ],
    );
  }
}

class _BatchBar extends ConsumerWidget {
  const _BatchBar(this.selection);
  final DocumentSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final docs = selection.documents;
    final enabled = docs.isNotEmpty;
    final allFavourite = enabled && docs.every((d) => d.isFavourite);
    final actions = [
      (
        const Key('batch-favourite'),
        allFavourite ? Icons.star_outline_rounded : Icons.star_rounded,
        allFavourite ? l.batchUnfavourite : l.batchFavourite,
        () => _favourite(context, ref, docs, !allFavourite),
      ),
      (
        const Key('batch-move'),
        Icons.drive_file_move_outlined,
        l.batchMove,
        () => _move(context, ref, docs),
      ),
      (
        const Key('batch-category'),
        Icons.category_outlined,
        l.batchCategory,
        () => _category(context, ref, docs),
      ),
      (
        const Key('batch-export'),
        Icons.ios_share_outlined,
        l.batchExport,
        () => _export(context, ref, docs),
      ),
      (
        const Key('batch-delete'),
        Icons.delete_outline,
        l.batchDelete,
        () => _delete(context, ref, docs),
      ),
    ];
    return BottomAppBar(
      height: null,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          for (final (key, icon, label, onTap) in actions)
            Expanded(
              child: Semantics(
                button: true,
                enabled: enabled,
                label: label,
                excludeSemantics: true,
                child: InkWell(
                  key: key,
                  borderRadius: BorderRadius.circular(12),
                  onTap: enabled ? onTap : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Opacity(
                      opacity: enabled ? 1 : .4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<String?> Function(DocumentRepository repo) action,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = await ref.read(documentRepositoryProvider.future);
      final message = await action(repo);
      if (message == null) return;
      selection.end();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on SecurityFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorFor(e.code))));
    } on StateError {
      messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
    }
  }

  Future<void> _favourite(
    BuildContext context,
    WidgetRef ref,
    List<VaultDocument> docs,
    bool favourite,
  ) => _run(context, ref, (repo) async {
    await repo.setFavouriteMany(docs.map((d) => d.id), favourite);
    if (!context.mounted) return null;
    return AppLocalizations.of(context).batchUpdated(docs.length);
  });

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    List<VaultDocument> docs,
  ) async {
    final l = AppLocalizations.of(context);
    final folders = await ref.read(foldersProvider.future);
    if (!context.mounted) return;
    final same = docs.map((d) => d.folderId).toSet();
    final picked = await pickOption<int?>(
      context,
      title: l.batchMoveTitle(docs.length),
      current: same.length == 1 ? same.single : -1,
      options: [(null, l.noFolder), for (final f in folders) (f.id, f.name)],
    );
    if (picked == null || !context.mounted) return;
    await _run(context, ref, (repo) async {
      await repo.moveToFolderMany(docs.map((d) => d.id), picked.$1);
      return l.batchUpdated(docs.length);
    });
  }

  Future<void> _category(
    BuildContext context,
    WidgetRef ref,
    List<VaultDocument> docs,
  ) async {
    final l = AppLocalizations.of(context);
    final categories = await ref.read(categoriesProvider.future);
    if (!context.mounted) return;
    final same = docs.map((d) => d.categoryId).toSet();
    final picked = await pickOption<int?>(
      context,
      title: l.batchCategoryTitle(docs.length),
      current: same.length == 1 ? same.single : -1,
      options: [
        (null, l.noCategory),
        for (final c in categories) (c.id, l.categoryName(c)),
      ],
    );
    if (picked == null || !context.mounted) return;
    await _run(context, ref, (repo) async {
      await repo.setCategoryMany(docs.map((d) => d.id), picked.$1);
      return l.batchUpdated(docs.length);
    });
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<VaultDocument> docs,
  ) {
    final l = AppLocalizations.of(context);
    return _run(context, ref, (repo) async {
      final r = await ref
          .read(lockControllerProvider.notifier)
          .runWithoutAutoLock(
            () => repo.exportMany(
              'DocSafe export ${isoDate(DateTime.now())}',
              docs,
            ),
          );
      if (r == null) return null; // Folder picker cancelled.
      final total = r.exported + r.failed;
      return r.failed == 0
          ? l.exportAllResult(r.exported, total)
          : '${l.exportAllResult(r.exported, total)} '
                '${l.exportAllFailedNote(r.failed)}';
    });
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    List<VaultDocument> docs,
  ) async {
    final l = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l.batchDeleteTitle,
      message: l.batchDeleteBody(docs.length),
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _run(context, ref, (repo) async {
      await repo.moveToTrashMany(docs.map((d) => d.id));
      return l.batchDeleted(docs.length);
    });
  }
}
