import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/data/models/search_models.dart';
import 'package:quizhub/data/repositories/search_repository.dart';
import 'package:quizhub/features/search/cubit/global_search_cubit.dart';

class _FakeSearchRepository implements SearchRepository {
  final searchedQueries = <String>[];
  final searchedTypes = <SearchType>[];
  final savedQueries = <String>[];
  final deletedIds = <int>[];

  Future<GlobalSearchPage> Function(String, SearchType)? searchHandler;
  Future<SavedSearchResponse> Function()? historyHandler;
  Future<void> Function(String)? saveHandler;
  Future<void> Function(int)? deleteHandler;

  @override
  Future<GlobalSearchPage> search({
    required String query,
    SearchType type = SearchType.all,
    int? after,
    int limit = SearchRepository.defaultPageSize,
  }) {
    searchedQueries.add(query);
    searchedTypes.add(type);
    return searchHandler?.call(query, type) ??
        Future.value(const GlobalSearchPage());
  }

  @override
  Future<SavedSearchResponse> getSavedSearches() =>
      historyHandler?.call() ?? Future.value(const SavedSearchResponse());

  @override
  Future<void> saveSearch(String query) {
    savedQueries.add(query);
    return saveHandler?.call(query) ?? Future.value();
  }

  @override
  Future<void> deleteSavedSearch(int id) {
    deletedIds.add(id);
    return deleteHandler?.call(id) ?? Future.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GlobalSearchItem _hit(int id) => GlobalSearchItem(
  type: SearchType.user,
  user: SearchUser(userId: id, fullName: 'User $id'),
);

void main() {
  late _FakeSearchRepository repository;
  late GlobalSearchCubit cubit;

  setUp(() {
    repository = _FakeSearchRepository();
    cubit = GlobalSearchCubit(repository);
  });

  tearDown(() async => cubit.close());

  test('trims query before searching and saving history', () async {
    await cubit.search('  flutter  ');
    expect(repository.searchedQueries, ['flutter']);
    expect(repository.savedQueries, ['flutter']);
    expect(cubit.state.query, 'flutter');
  });

  test('empty query clears results and skips repository calls', () async {
    repository.searchHandler = (query, type) async =>
        GlobalSearchPage(items: [_hit(1)]);
    await cubit.search('flutter', saveToHistory: false);
    expect(cubit.resultsCubit.state.items, hasLength(1));

    await cubit.search('   ');

    expect(repository.searchedQueries, ['flutter']);
    expect(repository.savedQueries, isEmpty);
    expect(cubit.state.query, isEmpty);
    expect(cubit.resultsCubit.state.items, isEmpty);
  });

  test('changing filter searches again without saving history', () async {
    await cubit.search('database');
    await cubit.changeType(SearchType.question);

    expect(repository.searchedQueries, ['database', 'database']);
    expect(repository.searchedTypes, [SearchType.all, SearchType.question]);
    expect(repository.savedQueries, ['database']);
    expect(cubit.state.selectedType, SearchType.question);
  });

  test('history loading failure is exposed in state', () async {
    repository.historyHandler = () async => throw Exception('history failed');
    await cubit.loadInitialData();

    expect(cubit.state.isLoadingHistory, isFalse);
    expect(cubit.state.historyError, contains('history failed'));
  });

  test('history save failure does not discard successful results', () async {
    repository.searchHandler = (query, type) async =>
        GlobalSearchPage(items: [_hit(1)]);
    repository.saveHandler = (query) async => throw Exception('save failed');

    await cubit.search('flutter');

    expect(cubit.resultsCubit.state.items, hasLength(1));
    expect(cubit.resultsCubit.state.items.single.user!.userId, 1);
    expect(cubit.state.query, 'flutter');
  });

  test('stale search response cannot overwrite the latest results', () async {
    final first = Completer<GlobalSearchPage>();
    final second = Completer<GlobalSearchPage>();
    repository.searchHandler = (query, type) =>
        query == 'first' ? first.future : second.future;

    final firstSearch = cubit.search('first', saveToHistory: false);
    final secondSearch = cubit.search('second', saveToHistory: false);

    second.complete(GlobalSearchPage(items: [_hit(2)]));
    await secondSearch;
    first.complete(GlobalSearchPage(items: [_hit(1)]));
    await firstSearch;

    expect(cubit.state.query, 'second');
    expect(cubit.resultsCubit.state.items, hasLength(1));
    expect(cubit.resultsCubit.state.items.single.user!.userId, 2);
  });

  test('failed delete keeps saved item in local history', () async {
    final saved = SavedSearch(savedSearchId: 5, queryText: 'Flutter');
    repository.historyHandler = () async =>
        SavedSearchResponse(savedSearches: [saved]);
    await cubit.loadInitialData();

    repository.deleteHandler = (id) async => throw Exception('delete failed');
    await cubit.deleteSavedSearch(5);

    expect(repository.deletedIds, [5]);
    expect(cubit.state.savedSearches, [saved]);
    expect(cubit.state.historyError, contains('delete failed'));
  });
}
