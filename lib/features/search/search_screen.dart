import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/states.dart';
import '../../core/entitlement/entitlement.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../premium/premium_screen.dart';
import '../vault/widgets/document_list.dart';

/// Free search over titles, tags and (localised) category names.
/// Search inside recognised (OCR) text is Premium.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _insideText = true;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final premium = ref.watch(premiumUnlockedProvider);
    final lower = _query.toLowerCase();
    final matchingCategories = {
      for (final c in categories)
        if (lower.isNotEmpty && l.categoryName(c).toLowerCase().contains(lower))
          c.id,
    };
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.homeSearchHint,
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: l.clearValue,
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _query.isEmpty
          ? EmptyState(icon: Icons.search, title: l.searchEmptyQuery)
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilterChip(
                        key: const Key('search-inside-text'),
                        avatar: premium
                            ? null
                            : const Icon(Icons.lock_outline, size: 18),
                        label: Text(l.searchInsideText),
                        selected: premium && _insideText,
                        onSelected: (v) {
                          if (!premium) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    PremiumScreen(feature: l.ocrSearchFeature),
                              ),
                            );
                            return;
                          }
                          setState(() => _insideText = v);
                        },
                      ),
                    ),
                  ),
                ),
                DocumentSliverList(
                  docs: ref.watch(
                    documentsProvider(
                      DocumentQuery(
                        text: _query,
                        matchingCategoryIds: matchingCategories,
                        includeRecognizedText: premium && _insideText,
                      ),
                    ),
                  ),
                  empty: EmptyState(
                    icon: Icons.search_off,
                    title: l.searchNoResults(_query),
                  ),
                ),
              ],
            ),
    );
  }
}
