import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_exception.dart';
import '../core/storage/credential_storage.dart';
import '../core/storage/token_storage.dart';
import '../data/models/saved_account.dart';
import 'preview_backend.dart';

/// Cấu hình riêng cho bản test chat hai tài khoản, không dùng token server thật.
class SharedChatDemoConfig {
  final String apiBaseUrl;
  final int userId;

  SharedChatDemoConfig({
    String apiBaseUrl = 'http://127.0.0.1:8787/api/v1',
    this.userId = 1,
  }) : apiBaseUrl = apiBaseUrl.replaceFirst(RegExp(r'/+$'), '') {
    final uri = Uri.tryParse(this.apiBaseUrl);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'CHAT_DEMO_URL phải là URL http/https hợp lệ.',
      );
    }
    if (userId != 1 && userId != 2) {
      throw const FormatException(
        'CHAT_DEMO_USER_ID chỉ nhận 1 (An) hoặc 2 (Lan).',
      );
    }
  }

  factory SharedChatDemoConfig.fromEnvironment() => SharedChatDemoConfig(
    apiBaseUrl: const String.fromEnvironment(
      'CHAT_DEMO_URL',
      defaultValue: 'http://127.0.0.1:8787/api/v1',
    ),
    userId: const int.fromEnvironment('CHAT_DEMO_USER_ID', defaultValue: 1),
  );

  String get displayName => userId == 1 ? 'Nguyễn Văn An' : 'Trần Thị Lan';
  String get webSocketUrl {
    final uri = Uri.parse(apiBaseUrl);
    return uri
        .replace(
          scheme: uri.scheme == 'https' ? 'wss' : 'ws',
          path: '${uri.path}/ws/websocket',
        )
        .toString();
  }

  String get cachePrefix =>
      'shared_chat_demo_${base64Url.encode(utf8.encode(apiBaseUrl)).replaceAll('=', '')}_$userId.';
}

/// Danh tính cố định theo bản test (Samsung An, trình duyệt Lan).
class SharedChatDemoTokens extends TokenStorage {
  final int userId;
  bool _active = true;
  SharedChatDemoTokens(this.userId);

  @override
  String? get accessToken => _active ? 'chat-demo-$userId' : null;
  @override
  String? get refreshToken => _active ? 'chat-demo-refresh-$userId' : null;
  @override
  bool get hasTokens => _active;
  @override
  Future<void> load() async {}
  @override
  Future<void> clear() async => _active = false;
  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (accessToken != 'chat-demo-$userId') {
      throw const ApiException(
        type: ApiErrorType.validation,
        message:
            'Tài khoản không khớp bản test đang mở. Hãy chạy bản test của tài khoản còn lại.',
      );
    }
    _active = true;
  }
}

/// Bản demo không đọc hoặc sửa thẻ tài khoản thật đang lưu trên thiết bị.
class SharedChatDemoCredentials extends CredentialStorage {
  @override
  Future<SavedAccount?> read() async => null;
  @override
  Future<void> save(SavedAccount account) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> updateProfile({
    required String email,
    String? fullName,
    String? avatarUrl,
  }) async {}
}

/// Chat/user dùng API chung; các phần bài viết/ngân hàng đề vẫn dùng dữ liệu mẫu.
class SharedChatDemoAdapter implements HttpClientAdapter {
  final SharedChatDemoConfig config;
  final HttpClientAdapter _remote;
  final HttpClientAdapter _local;

  SharedChatDemoAdapter({
    required this.config,
    SharedPreferences? preferences,
    HttpClientAdapter? remoteAdapter,
    HttpClientAdapter? localAdapter,
  }) : _remote = remoteAdapter ?? Dio().httpClientAdapter,
       _local = localAdapter ?? PreviewBackend(preferences: preferences);

  static bool isSharedPath(String path) =>
      path == '/health' ||
      path.startsWith('/auth/') ||
      path == '/conversations' ||
      path.startsWith('/conversations/') ||
      RegExp(r'^/messages/\d+$').hasMatch(path) ||
      path == '/users/me' ||
      RegExp(r'^/users/\d+$').hasMatch(path) ||
      RegExp(r'^/users/\d+/relationship-stats$').hasMatch(path) ||
      path == '/search' ||
      path == '/blocks' ||
      path.startsWith('/blocks/') ||
      path == '/medias/upload' ||
      path.startsWith('/media/');

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (Uri.tryParse(options.path)?.hasScheme ?? false) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: const FormatException(
          'Bản demo chỉ gọi đường dẫn API của máy chủ test đã chọn.',
        ),
      );
    }
    if (!isSharedPath(options.path)) {
      return _local.fetch(options, requestStream, cancelFuture);
    }
    final headers = Map<String, dynamic>.from(options.headers);
    // Không chuyển token phiên khác sang mock, kể cả khi gọi nhầm adapter.
    headers.removeWhere(
      (key, value) =>
          key.toLowerCase() == 'authorization' &&
          value != 'Bearer chat-demo-${config.userId}',
    );
    return _remote.fetch(
      options.copyWith(
        baseUrl: config.apiBaseUrl,
        headers: headers,
        followRedirects: false,
      ),
      requestStream,
      cancelFuture,
    );
  }

  @override
  void close({bool force = false}) {
    _remote.close(force: force);
    _local.close(force: force);
  }
}

/// Tách hoàn toàn cache demo theo máy chủ và tài khoản, giữ dữ liệu preview cũ.
class SharedChatDemoPreferences implements SharedPreferences {
  final SharedPreferences _delegate;
  final String prefix;
  SharedChatDemoPreferences(this._delegate, {required this.prefix});
  String _key(String key) => '$prefix$key';

  @override
  Set<String> getKeys() => _delegate
      .getKeys()
      .where((key) => key.startsWith(prefix))
      .map((key) => key.substring(prefix.length))
      .toSet();
  @override
  Object? get(String key) => _delegate.get(_key(key));
  @override
  bool containsKey(String key) => _delegate.containsKey(_key(key));
  @override
  String? getString(String key) => _delegate.getString(_key(key));
  @override
  List<String>? getStringList(String key) => _delegate.getStringList(_key(key));
  @override
  bool? getBool(String key) => _delegate.getBool(_key(key));
  @override
  int? getInt(String key) => _delegate.getInt(_key(key));
  @override
  double? getDouble(String key) => _delegate.getDouble(_key(key));
  @override
  Future<bool> setString(String key, String value) =>
      _delegate.setString(_key(key), value);
  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _delegate.setStringList(_key(key), value);
  @override
  Future<bool> setBool(String key, bool value) =>
      _delegate.setBool(_key(key), value);
  @override
  Future<bool> setInt(String key, int value) =>
      _delegate.setInt(_key(key), value);
  @override
  Future<bool> setDouble(String key, double value) =>
      _delegate.setDouble(_key(key), value);
  @override
  Future<bool> remove(String key) => _delegate.remove(_key(key));
  @override
  Future<void> reload() => _delegate.reload();
  @override
  Future<bool> clear() async {
    var success = true;
    for (final key in getKeys()) {
      if (!await remove(key)) success = false;
    }
    return success;
  }

  @override
  Future<bool> commit() async => true;
}
