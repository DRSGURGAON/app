import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/states.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/document_repository.dart';
import '../vault/widgets/document_list.dart';

enum PickKind { pdf, image }

/// Selects documents from the vault. Multi-select keeps the tap order.
class DocumentPickerScreen extends ConsumerStatefulWidget {
  const DocumentPickerScreen({
    super.key,
    required this.title,
    required this.kind,
    this.multiple = false,
    this.minimum = 1,
  });

  final String title;
  final PickKind kind;
  final bool multiple;
  final int minimum;

  @override
  ConsumerState<DocumentPickerScreen> createState() =>
      _DocumentPickerScreenState();
}

class _DocumentPickerScreenState extends ConsumerState<DocumentPickerScreen> {
  final List<VaultDocument> _selected = [];

  bool _matches(VaultDocument d) =>
      widget.kind == PickKind.pdf ? d.isPdf : d.isImage;

  void _toggle(VaultDocument d) {
    if (!widget.multiple) {
      Navigator.of(context).pop([d]);
      return;
    }
    setState(() {
      final i = _selected.indexWhere((x) => x.id == d.id);
      if (i >= 0) {
        _selected.removeAt(i);
      } else {
        _selected.add(d);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final docs = ref.watch(documentsProvider(const DocumentQuery()));
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: docs.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: errorMessageFor(l, e)),
        data: (all) {
          final items = all.where(_matches).toList();
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.search_off,
              title: l.pickNoneAvailable,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final d = items[i];
              final order = _selected.indexWhere((x) => x.id == d.id);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: order >= 0
                        ? Text('${order + 1}')
                        : Icon(
                            d.isPdf
                                ? Icons.picture_as_pdf_outlined
                                : Icons.image_outlined,
                          ),
                  ),
                  title: Text(
                    d.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(formatBytes(d.sizeBytes, locale)),
                  trailing: widget.multiple
                      ? Checkbox(
                          value: order >= 0,
                          onChanged: (_) => _toggle(d),
                        )
                      : const Icon(Icons.chevron_right),
                  selected: order >= 0,
                  onTap: () => _toggle(d),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: !widget.multiple
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selected.length < widget.minimum
                            ? l.pickMinimum(widget.minimum)
                            : l.pickSelectedCount(_selected.length),
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(120, 48),
                      ),
                      onPressed: _selected.length < widget.minimum
                          ? null
                          : () => Navigator.of(context).pop(List.of(_selected)),
                      child: Text(l.pickNext),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

Future<List<VaultDocument>?> pickDocuments(
  BuildContext context, {
  required String title,
  required PickKind kind,
  bool multiple = false,
  int minimum = 1,
}) => Navigator.of(context).push<List<VaultDocument>>(
  MaterialPageRoute(
    builder: (_) => DocumentPickerScreen(
      title: title,
      kind: kind,
      multiple: multiple,
      minimum: minimum,
    ),
  ),
);
