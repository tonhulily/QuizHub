
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_endpoints.dart';
import 'package:quizhub/core/network/response_codes.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/firebase/firebase_fid_sync_service.dart';
import 'package:quizhub/core/firebase/firebase_installation_service.dart';
import 'package:quizhub/core/storage/token_storage.dart';

class FakeTokenStorage extends TokenStorage {
  bool loggedIn;

  FakeTokenStorage({this.loggedIn = true});

  @override
  bool get hasTokens => loggedIn;
}

class FakeFirebaseInstallationService
    extends FirebaseInstallationService {
  String? currentFid;

  final StreamController<String> controller =
      StreamController<String>.broadcast();

  @override
  Future<String?> getFid() async => currentFid;

  @override
  Stream<String> get onFidChanged => controller.stream;

  Future<void> disposeStream() => controller.close();
}


class FakeHttpClientAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  final Completer<void> _requestReceived = Completer<void>();

  Completer<ResponseBody>? responseCompleter;
  String responseCode = ResponseCodes.success;

  Future<void> get requestReceived => _requestReceived.future;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (!_requestReceived.isCompleted) {
      _requestReceived.complete();
    }

    if (responseCompleter != null) {
      return responseCompleter!.future;
    }

    return _response();
  }

  ResponseBody _response() {
    return ResponseBody.fromString(
      jsonEncode({
        'code': responseCode,
        'message': 'Test response',
        'data': {},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  void completeRequest() {
    responseCompleter?.complete(_response());
  }

  @override
  void close({bool force = false}) {}
}


void main() {
  late FakeTokenStorage tokens;
  late FakeFirebaseInstallationService installation;
  late FakeHttpClientAdapter adapter;
  late FirebaseFidSyncService service;

  setUp(() {
    tokens = FakeTokenStorage();
    installation = FakeFirebaseInstallationService();
    adapter = FakeHttpClientAdapter();

    final api = ApiClient(
      tokens: tokens,
      events: SessionEvents(),
      baseUrl: 'https://test.local',
      adapter: adapter,
    );

    service = FirebaseFidSyncService(
      api,
      tokens,
      installation,
    );
  });

  tearDown(() async {
    await service.dispose();
    await installation.disposeStream();
  });

  group('syncFid', () {
    test('không đồng bộ khi người dùng chưa đăng nhập', () async {
      tokens.loggedIn = false;

      await service.syncFid('fid-001');

      expect(adapter.requests, isEmpty);
    });

    test('không đồng bộ khi FID rỗng', () async {
      await service.syncFid('');

      expect(adapter.requests, isEmpty);
    });

    test('gửi FID lên backend', () async {
      await service.syncFid('fid-001');

      expect(adapter.requests, hasLength(1));

      final request = adapter.requests.first;

      expect(request.method, 'POST');
      expect(request.path, contains(ApiEndpoints.deviceFid));
      expect(request.data, {'fid': 'fid-001'});
    });

    test('không gửi lại FID đã đồng bộ thành công', () async {
      await service.syncFid('fid-001');
      await service.syncFid('fid-001');

      expect(adapter.requests, hasLength(1));
    });

    test('cho phép đồng bộ FID mới', () async {
      await service.syncFid('fid-001');
      await service.syncFid('fid-002');

      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[0].data, {'fid': 'fid-001'});
      expect(adapter.requests[1].data, {'fid': 'fid-002'});
    });

    test('không gửi request trùng khi request trước đang xử lý', () async {
      adapter.responseCompleter = Completer<ResponseBody>();

      final firstCall = service.syncFid('fid-001');

      // Chờ request thực sự đến adapter.
      await adapter.requestReceived;

      final secondCall = service.syncFid('fid-001');

      await secondCall;

      expect(adapter.requests, hasLength(1));

      adapter.completeRequest();

      await firstCall;
    });

    test('cho phép thử lại sau khi API gặp lỗi', () async {
      adapter.responseCode = ResponseCodes.databaseError;

      await service.syncFid('fid-001');

      expect(adapter.requests, hasLength(1));

      // Lần gọi tiếp theo vẫn được phép gửi vì lần trước thất bại.
      adapter.responseCode = ResponseCodes.success;

      await service.syncFid('fid-001');

      expect(adapter.requests, hasLength(2));
    });

    test('không đánh dấu FID đã đồng bộ khi API thất bại', () async {
      adapter.responseCode = ResponseCodes.databaseError;

      await service.syncFid('fid-001');

      adapter.responseCode = ResponseCodes.success;

      await service.syncFid('fid-001');

      expect(adapter.requests, hasLength(2));
    });
  });

  group('syncCurrentFid', () {
    test('không gọi getFid khi chưa đăng nhập', () async {
      tokens.loggedIn = false;
      installation.currentFid = 'fid-001';

      await service.syncCurrentFid();

      expect(adapter.requests, isEmpty);
    });

    test('đồng bộ FID hiện tại khi đã đăng nhập', () async {
      installation.currentFid = 'fid-001';

      await service.syncCurrentFid();

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.first.data, {'fid': 'fid-001'});
    });

    test('bỏ qua khi Firebase không trả về FID', () async {
      installation.currentFid = null;

      await service.syncCurrentFid();

      expect(adapter.requests, isEmpty);
    });
  });

  group('start', () {
    test('đăng ký listener và đồng bộ FID hiện tại', () async {
      installation.currentFid = 'fid-initial';

      await service.start();
      await adapter.requestReceived;

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.first.data, {'fid': 'fid-initial'});
    });

    test('chỉ đăng ký listener một lần khi start nhiều lần', () async {
      var listenCount = 0;

      final controller = StreamController<String>.broadcast(
        onListen: () => listenCount++,
      );

      final customInstallation = _StreamInstallation(
        controller.stream,
      );

      final api = ApiClient(
        tokens: tokens,
        events: SessionEvents(),
        baseUrl: 'https://test.local',
        adapter: adapter,
      );

      final customService = FirebaseFidSyncService(
        api,
        tokens,
        customInstallation,
      );

      await customService.start();
      await customService.start();

      expect(listenCount, 1);

      await customService.dispose();
      await controller.close();
    });

    test('đồng bộ khi FID thay đổi', () async {
      await service.start();

      installation.controller.add('fid-new');

      await adapter.requestReceived;

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.first.data, {'fid': 'fid-new'});
    });

    test('không đồng bộ FID thay đổi khi chưa đăng nhập', () async {
      tokens.loggedIn = false;

      await service.start();

      installation.controller.add('fid-new');

      await Future<void>.delayed(Duration.zero);

      expect(adapter.requests, isEmpty);
    });
  });

  group('dispose', () {
    test('hủy listener FID', () async {
      await service.start();

      await service.dispose();

      installation.controller.add('fid-after-dispose');

      await Future<void>.delayed(Duration.zero);

      expect(adapter.requests, isEmpty);
    });

    test('có thể start lại sau dispose', () async {
      await service.start();
      await service.dispose();
    
      installation.controller.add('fid-before-restart');
    
      await Future<void>.delayed(Duration.zero);
    
      expect(adapter.requests, isEmpty);
    
      await service.start();
    
      installation.controller.add('fid-after-restart');
    
      await adapter.requestReceived;
    
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.first.data, {'fid': 'fid-after-restart'});
    });
  });
}

class _StreamInstallation extends FirebaseInstallationService {
  final Stream<String> stream;

  _StreamInstallation(this.stream);

  @override
  Stream<String> get onFidChanged => stream;

  @override
  Future<String?> getFid() async => null;
}
