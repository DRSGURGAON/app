import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/states.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../vault/widgets/document_list.dart';

/// Free search over titles, tags and (localised) category names.
/// OCR text search inside documents is a Premium feature (Phase 5/6).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

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
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                DocumentSliverList(
                  docs: ref.watch(
                    documentsProvider(
                      DocumentQuery(
                        text: _query,
                        matchingCategoryIds: matchingCategories,
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
