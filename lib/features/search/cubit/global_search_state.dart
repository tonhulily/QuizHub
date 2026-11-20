// lib/features/search/cubit/global_search_state.dart
import 'package:equatable/equatable.dart';

import '../../../data/models/search_models.dart';

class GlobalSearchState extends Equatable {
  final String query;
  final SearchType selectedType;

  final List<SavedSearch> savedSearches;
  final List<String> trendingSearches;

  final bool isLoadingHistory;
  final String? historyError;

  const GlobalSearchState({
    this.query = '',
    this.selectedType = SearchType.all,
    this.savedSearches = const [],
    this.trendingSearches = const [],
    this.isLoadingHistory = false,
    this.historyError,
  });

  bool get hasSearched => query.isNotEmpty;

  GlobalSearchState copyWith({
    String? query,
    SearchType? selectedType,
    List<SavedSearch>? savedSearches,
    List<String>? trendingSearches,
    bool? isLoadingHistory,
    String? historyError,
    bool clearHistoryError = false,
  }) {
    return GlobalSearchState(
      query: query ?? this.query,
      selectedType: selectedType ?? this.selectedType,
      savedSearches: savedSearches ?? this.savedSearches,
      trendingSearches: trendingSearches ?? this.trendingSearches,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      historyError: clearHistoryError
          ? null
          : historyError ?? this.historyError,
    );
  }

  @override
  List<Object?> get props => [
    query,
    selectedType,
    savedSearches,
    trendingSearches,
    isLoadingHistory,
    historyError,
  ];
}
