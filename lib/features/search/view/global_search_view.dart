// lib/features/search/view/global_search_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/locator.dart';
import '../../../core/bloc/paged_cubit.dart';
import '../../../data/models/search_models.dart';
import '../../../data/repositories/search_repository.dart';
import '../cubit/global_search_cubit.dart';
import '../cubit/global_search_state.dart';
import '../widgets/global_search_bar.dart';
import '../widgets/search_filter_tabs.dart';
import '../widgets/search_result_list.dart';
import '../widgets/search_suggestions.dart';

class GlobalSearchView extends StatefulWidget {
  const GlobalSearchView({super.key});

  @override
  State<GlobalSearchView> createState() => _GlobalSearchViewState();
}

class _GlobalSearchViewState extends State<GlobalSearchView> {
  late final GlobalSearchCubit _cubit;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _cubit = GlobalSearchCubit(getIt<SearchRepository>())
      ..loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cubit.close();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    _searchController.text = query.trim();
    await _cubit.search(query);
  }

  void _clearSearch() {
    _searchController.clear();
    _cubit.search('');
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cubit),
        BlocProvider<PagedCubit<GlobalSearchItem>>.value(
          value: _cubit.resultsCubit,
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: GlobalSearchBar(
            controller: _searchController,
            onSubmitted: _performSearch,
            onClear: _clearSearch,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              BlocBuilder<GlobalSearchCubit, GlobalSearchState>(
                buildWhen: (previous, current) =>
                    previous.hasSearched != current.hasSearched ||
                    previous.selectedType != current.selectedType,
                builder: (context, state) {
                  if (!state.hasSearched) {
                    return const SizedBox.shrink();
                  }

                  return SearchFilterTabs(
                    selectedType: state.selectedType,
                    onChanged: _cubit.changeType,
                  );
                },
              ),
              Expanded(
                child: BlocBuilder<GlobalSearchCubit, GlobalSearchState>(
                  builder: (context, state) {
                    if (!state.hasSearched) {
                      return SearchSuggestions(
                        savedSearches: state.savedSearches,
                        trendingSearches: state.trendingSearches,
                        isLoading: state.isLoadingHistory,
                        error: state.historyError,
                        onSelect: _performSearch,
                        onDelete: _cubit.deleteSavedSearch,
                      );
                    }

                    return SearchResultList();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}