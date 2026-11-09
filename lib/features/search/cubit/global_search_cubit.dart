// lib/features/search/cubit/global_search_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../data/models/cursor_page.dart';
import '../../../data/models/search_models.dart';
import '../../../data/repositories/search_repository.dart';
import 'global_search_state.dart';

class GlobalSearchCubit extends Cubit<GlobalSearchState> {
  final SearchRepository _repository;

  late final PagedCubit<GlobalSearchItem> resultsCubit;

  int _searchRequestId = 0;
  int _historyRequestId = 0;

  GlobalSearchCubit(this._repository)
      : super(const GlobalSearchState()) {
    resultsCubit = PagedCubit<GlobalSearchItem>((after) async {
      final query = state.query;
      final type = state.selectedType;

      if (query.isEmpty) {
        return const CursorPage<GlobalSearchItem>();
      }

      return _repository.search(
        query: query,
        type: type,
        after: int.tryParse(after ?? ''),
      );
    });
  }

  /// Tải lịch sử và xu hướng khi mở Search Page.
  Future<void> loadInitialData() async {
    final requestId = ++_historyRequestId;

    emit(state.copyWith(
      isLoadingHistory: true,
      clearHistoryError: true,
    ));

    try {
      final response = await _repository.getSavedSearches();

      if (isClosed || requestId != _historyRequestId) return;

      emit(state.copyWith(
        savedSearches: response.savedSearches,
        trendingSearches: response.trendingSearches,
        isLoadingHistory: false,
      ));
    } catch (e) {
      if (isClosed || requestId != _historyRequestId) return;

      emit(state.copyWith(
        isLoadingHistory: false,
        historyError: e.toString(),
      ));
    }
  }

  /// Tìm kiếm mới.
  ///
  /// saveToHistory chỉ bật khi người dùng xác nhận tìm kiếm.
  Future<void> search(
    String query, {
    SearchType? type,
    bool saveToHistory = true,
  }) async {
    final normalizedQuery = query.trim();
    final selectedType = type ?? state.selectedType;

    final requestId = ++_searchRequestId;

    emit(state.copyWith(
      query: normalizedQuery,
      selectedType: selectedType,
    ));

    // Hủy hiệu lực request cũ và xóa kết quả cũ.
    resultsCubit.reset();

    if (normalizedQuery.isEmpty) return;

    await resultsCubit.load();

    // Không xử lý tiếp nếu đã có tìm kiếm mới.
    if (isClosed || requestId != _searchRequestId) return;

    // Chỉ lưu lịch sử nếu tải trang đầu thành công.
    if (saveToHistory &&
        resultsCubit.state.status == PagedStatus.loaded) {
      await _saveSearchHistory(normalizedQuery);
    }
  }

  /// Đổi bộ lọc kết quả.
  Future<void> changeType(SearchType type) async {
    if (type == state.selectedType) return;

    if (state.query.isEmpty) {
      emit(state.copyWith(selectedType: type));
      return;
    }

    await search(
      state.query,
      type: type,
      saveToHistory: false,
    );
  }

  /// Chọn từ khóa trong lịch sử hoặc xu hướng.
  Future<void> searchFromHistory(String query) async {
    await search(query, saveToHistory: true);
  }

  /// Xóa một mục lịch sử.
  Future<void> deleteSavedSearch(int id) async {
    try {
      await _repository.deleteSavedSearch(id);

      if (isClosed) return;

      emit(state.copyWith(
        savedSearches: state.savedSearches
            .where((item) => item.savedSearchId != id)
            .toList(),
      ));
    } catch (e) {
      emit(state.copyWith(historyError: e.toString()));
    }
  }

  Future<void> _saveSearchHistory(String query) async {
    try {
      await _repository.saveSearch(query);

      final response = await _repository.getSavedSearches();

      if (isClosed) return;

      emit(state.copyWith(
        savedSearches: response.savedSearches,
        trendingSearches: response.trendingSearches,
      ));
    } catch (_) {
      // Lỗi lưu lịch sử không ảnh hưởng kết quả tìm kiếm.
    }
  }

  @override
  Future<void> close() async {
    await resultsCubit.close();
    return super.close();
  }
}
