// lib/data/repositories/search_repository.dart
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/search_models.dart';

class SearchRepository {
  final ApiClient _api;

  SearchRepository(this._api);

  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  /// Tìm kiếm toàn cục.
  Future<GlobalSearchPage> search({
    required String query,
    SearchType type = SearchType.all,
    int? after,
    int limit = defaultPageSize,
  }) {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return Future.value(const GlobalSearchPage());
    }

    if (!SearchType.values.contains(type)) {
      throw ArgumentError.value(
        type,
        'type',
        'Loại tìm kiếm không hợp lệ',
      );
    }

    return _api.get<GlobalSearchPage>(
      ApiEndpoints.search,
      query: {
        'query': normalizedQuery,
        'type': type.apiValue,
        'after': after,
        'limit': limit.clamp(1, maxPageSize).toInt(),
      },
      parser: GlobalSearchPage.fromJson,
    );
  }

  /// Lấy lịch sử tìm kiếm cá nhân và từ khóa thịnh hành.
  Future<SavedSearchResponse> getSavedSearches() {
    return _api.get<SavedSearchResponse>(
      ApiEndpoints.searchSaved,
      parser: SavedSearchResponse.fromJson,
    );
  }

  /// Ghi nhận từ khóa sau khi người dùng xác nhận tìm kiếm.
  Future<void> saveSearch(String query) {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      throw ArgumentError.value(
        query,
        'query',
        'Từ khóa tìm kiếm không được để trống',
      );
    }

    return _api.postVoid(
      ApiEndpoints.searchSaved,
      body: {'query': normalizedQuery},
    );
  }

  /// Xóa một từ khóa khỏi lịch sử tìm kiếm.
  Future<void> deleteSavedSearch(int id) {
    return _api.deleteVoid(
      ApiEndpoints.searchSavedById(id),
    );
  }
}