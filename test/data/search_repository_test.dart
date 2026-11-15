import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_endpoints.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/models/search_models.dart';
import 'package:quizhub/data/repositories/search_repository.dart';

class _Tokens extends TokenStorage {
  @override
  String? get accessToken => 'access';
  @override
  String? get refreshToken => 'refresh';
  @override
  bool get hasTokens => true;
  @override
  Future<void> load() async {}
}

class _CaptureAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final ResponseBody Function(RequestOptions options) response;

  _CaptureAdapter(this.response);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return response(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> data) => ResponseBody.fromString(
  jsonEncode({'code': '0000', 'message': 'ok', 'data': data}),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  late SessionEvents events;
  late _CaptureAdapter adapter;
  late SearchRepository repository;

  setUp(() {
    events = SessionEvents();
    adapter = _CaptureAdapter(
      (_) => _json({
        'items': [],
        'total_hits': 0,
        'pagination': {'has_next': false},
      }),
    );
    final api = ApiClient(
      tokens: _Tokens(),
      events: events,
      baseUrl: 'https://example.test/api/v1',
      adapter: adapter,
    );
    repository = SearchRepository(api);
  });

  tearDown(() => events.dispose());

  test('empty search query returns empty page without HTTP request', () async {
    final page = await repository.search(query: '   ');

    expect(page.items, isEmpty);
    expect(adapter.requests, isEmpty);
  });

  test('search trims query and clamps page size to maximum', () async {
    await repository.search(
      query: '  flutter ',
      type: SearchType.user,
      after: 25,
      limit: 100,
    );

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, ApiEndpoints.search);
    expect(request.queryParameters['query'], 'flutter');
    expect(request.queryParameters['type'], 'USER');
    expect(request.queryParameters['after'], 25);
    expect(request.queryParameters['limit'], SearchRepository.maxPageSize);
  });

  test('saveSearch trims query in request body', () async {
    adapter = _CaptureAdapter((_) => _json({}));
    final api = ApiClient(
      tokens: _Tokens(),
      events: events,
      baseUrl: 'https://example.test/api/v1',
      adapter: adapter,
    );
    repository = SearchRepository(api);

    await repository.saveSearch('  data structure  ');

    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, ApiEndpoints.searchSaved);
    expect(adapter.requests.single.data, {'query': 'data structure'});
  });

  test('saveSearch rejects blank query before making request', () async {
    expect(() => repository.saveSearch('  '), throwsArgumentError);
    expect(adapter.requests, isEmpty);
  });

  test('deleteSavedSearch targets the selected history item', () async {
    adapter = _CaptureAdapter((_) => _json({}));
    final api = ApiClient(
      tokens: _Tokens(),
      events: events,
      baseUrl: 'https://example.test/api/v1',
      adapter: adapter,
    );
    repository = SearchRepository(api);

    await repository.deleteSavedSearch(42);

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, ApiEndpoints.searchSavedById(42));
  });
}
