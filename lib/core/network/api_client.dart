import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'response_codes.dart';
import 'session_events.dart';

typedef JsonParser<T> = T Function(dynamic data);

/// HTTP client duy nhất của app.
///
/// Mọi repository gọi qua đây và nhận về **phần `data`** đã được parse, hoặc
/// nhận [ApiException] nếu lỗi. Không repository / UI nào cần biết tới Dio.
///
/// ```dart
/// final profile = await _api.get(ApiEndpoints.me, parser: (d) => ProfileModel.fromJson(d));
/// ```
class ApiClient {
  final Dio _dio;

  ApiClient({
    required TokenStorage tokens,
    required SessionEvents events,
    String? baseUrl,
    @visibleForTesting HttpClientAdapter? adapter,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
           connectTimeout: AppConfig.connectTimeout,
           receiveTimeout: AppConfig.receiveTimeout,
           sendTimeout: AppConfig.sendTimeout,
           contentType: Headers.jsonContentType,
           responseType: ResponseType.json,
           headers: const {'Accept': 'application/json'},
           // Để tự đọc body lỗi (code/message) thay vì Dio ném exception sớm
           validateStatus: (status) => status != null && status < 300,
         ),
       ) {
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
        headers: const {'Accept': 'application/json'},
      ),
    );
    if (adapter != null) {
      _dio.httpClientAdapter = adapter;
      refreshDio.httpClientAdapter = adapter;
    }
    _dio.interceptors.add(
      AuthInterceptor(
        dio: _dio,
        refreshDio: refreshDio,
        tokens: tokens,
        events: events,
      ),
    );
    if (kDebugMode) {
      // Log gọn: 1 dòng cho request, 1 dòng cho response/lỗi
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            debugPrint('[API] -> ${o.method} ${o.path}');
            h.next(o);
          },
          onResponse: (r, h) {
            debugPrint('[API] <- ${r.statusCode} ${r.requestOptions.path}');
            h.next(r);
          },
          onError: (e, h) {
            debugPrint(
              '[API] x  ${e.response?.statusCode ?? e.type.name} '
              '${e.requestOptions.path}',
            );
            h.next(e);
          },
        ),
      );
    }
  }

  // ------------------------------------------------------------------
  // Public API
  // ------------------------------------------------------------------

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required JsonParser<T> parser,
    CancelToken? cancelToken,
  }) => _send<T>(
    'GET',
    path,
    query: query,
    parser: parser,
    cancelToken: cancelToken,
  );

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required JsonParser<T> parser,
  }) => _send<T>('POST', path, body: body, query: query, parser: parser);

  Future<T> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required JsonParser<T> parser,
  }) => _send<T>('PUT', path, body: body, query: query, parser: parser);

  Future<T> patch<T>(
    String path, {
    Object? body,
    required JsonParser<T> parser,
  }) => _send<T>('PATCH', path, body: body, parser: parser);

  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required JsonParser<T> parser,
  }) => _send<T>('DELETE', path, body: body, query: query, parser: parser);

  /// Các endpoint chỉ trả về code/message (data = null).
  Future<void> getVoid(String path, {Map<String, dynamic>? query}) =>
      _send<void>('GET', path, query: query, parser: (_) {});

  Future<void> postVoid(String path, {Object? body}) =>
      _send<void>('POST', path, body: body, parser: (_) {});

  Future<void> putVoid(String path, {Object? body}) =>
      _send<void>('PUT', path, body: body, parser: (_) {});

  Future<void> deleteVoid(String path, {Object? body}) =>
      _send<void>('DELETE', path, body: body, parser: (_) {});

  /// Upload multipart (vd /medias/upload).
  Future<T> upload<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? query,
    required JsonParser<T> parser,
    void Function(int sent, int total)? onProgress,
  }) => _send<T>(
    'POST',
    path,
    body: formData,
    query: query,
    parser: parser,
    onSendProgress: onProgress,
    contentType: Headers.multipartFormDataContentType,
  );

  /// PUT thẳng lên presigned URL (R2) - không đính kèm Authorization.
  Future<void> putToPresignedUrl(
    String url,
    List<int> bytes, {
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      await Dio().put<void>(
        url,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            Headers.contentLengthHeader: bytes.length,
            Headers.contentTypeHeader: contentType,
          },
          sendTimeout: AppConfig.sendTimeout,
        ),
        onSendProgress: onProgress,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  Future<T> _send<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required JsonParser<T> parser,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    String? contentType,
  }) async {
    try {
      var target = path;
      var hops = 0;
      while (true) {
        try {
          final response = await _dio.request<dynamic>(
            target,
            data: body,
            queryParameters: hops == 0 ? _cleanQuery(query) : null,
            cancelToken: cancelToken,
            onSendProgress: onSendProgress,
            options: Options(method: method, contentType: contentType),
          );
          return _unwrap<T>(response, parser);
        } on DioException catch (e) {
          // Dart HttpClient không tự theo 307/308 với POST/PUT/...; còn
          // validateStatus của ta coi >=300 là lỗi. Tự gọi lại 1 lần tới
          // Location (giữ nguyên method + body). FormData đã finalize nên
          // không gửi lại được.
          final next = _redirectTarget(e);
          if (next != null && hops >= _maxRedirects) {
            // Server cứ chuyển hướng mãi (thường do 1 node/proxy cấu hình sai)
            throw const ApiException(
              type: ApiErrorType.server,
              message:
                  'Máy chủ đang gặp sự cố (chuyển hướng liên tục). '
                  'Hãy đổi mạng (Wi-Fi/4G) hoặc thử lại sau.',
            );
          }
          if (next == null || body is FormData) rethrow;
          debugPrint('[API] redirect ${e.response?.statusCode} -> $next');
          target = next;
          hops++;
        }
      }
    } on DioException catch (e) {
      throw _mapError(e);
    } on ApiException {
      rethrow;
    } catch (e, st) {
      debugPrint('[API] unexpected error on $method $path: $e\n$st');
      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Dữ liệu trả về không đúng định dạng. Vui lòng thử lại.',
      );
    }
  }

  static const int _maxRedirects = 2;

  /// URL đích nếu [e] là 307/308 có header Location, ngược lại null.
  String? _redirectTarget(DioException e) {
    final res = e.response;
    final code = res?.statusCode;
    if (code != 307 && code != 308) return null;
    final location = res!.headers.value('location');
    if (location == null || location.isEmpty) return null;
    return res.requestOptions.uri.resolve(location).toString();
  }

  Map<String, dynamic>? _cleanQuery(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) cleaned[k] = v;
    });
    return cleaned;
  }

  /// Bóc vỏ `{code, message, data}`.
  T _unwrap<T>(Response<dynamic> response, JsonParser<T> parser) {
    final body = response.data;
    if (body is! Map) {
      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Máy chủ trả về dữ liệu không hợp lệ.',
      );
    }
    final code = body['code']?.toString();
    final message = body['message']?.toString() ?? '';
    if (!ResponseCodes.isSuccess(code)) {
      throw _fromBody(
        statusCode: response.statusCode,
        code: code,
        message: message,
        data: body['data'],
      );
    }
    return parser(body['data']);
  }

  ApiException _mapError(DioException e) {
    // Lỗi đã được AuthInterceptor chuẩn hoá
    if (e.error is ApiException) return e.error as ApiException;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          type: ApiErrorType.timeout,
          message: 'Kết nối quá chậm. Vui lòng thử lại.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          type: ApiErrorType.noConnection,
          message: 'Lỗi kết nối. Vui lòng kiểm tra mạng và thử lại.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          type: ApiErrorType.unknown,
          message: 'Yêu cầu đã bị huỷ.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          type: ApiErrorType.server,
          message: 'Chứng chỉ bảo mật không hợp lệ.',
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    if (e.error is SocketException) {
      return const ApiException(
        type: ApiErrorType.noConnection,
        message: 'Lỗi kết nối. Vui lòng kiểm tra mạng và thử lại.',
      );
    }

    final res = e.response;
    final data = res?.data;
    if (data is Map) {
      return _fromBody(
        statusCode: res?.statusCode,
        code: data['code']?.toString(),
        message: data['message']?.toString() ?? '',
        data: data['data'],
        path: e.requestOptions.path,
      );
    }
    return ApiException(
      type: (res?.statusCode ?? 0) >= 500
          ? ApiErrorType.server
          : ApiErrorType.unknown,
      message: 'Có lỗi xảy ra. Vui lòng thử lại sau.',
      statusCode: res?.statusCode,
    );
  }

  ApiException _fromBody({
    int? statusCode,
    String? code,
    required String message,
    dynamic data,
    String? path,
  }) {
    final fields = <String, String>{};
    if (data is List) {
      for (final item in data) {
        if (item is Map && item['field'] != null) {
          fields[item['field'].toString()] = item['message']?.toString() ?? '';
        }
      }
    }

    final isPublic =
        path != null && ApiEndpoints.publicPaths.any((p) => path.endsWith(p));

    ApiErrorType type;
    if (statusCode == 401 && !isPublic) {
      type = ApiErrorType.unauthorized;
    } else if (statusCode == 403) {
      type = ApiErrorType.forbidden;
    } else if (statusCode == 404) {
      type = ApiErrorType.notFound;
    } else if (code == ResponseCodes.missingParameter ||
        code == ResponseCodes.invalidParameterType ||
        code == ResponseCodes.invalidParameterValue) {
      type = ApiErrorType.validation;
    } else if ((statusCode ?? 0) >= 500) {
      type = ApiErrorType.server;
    } else {
      type = ApiErrorType.business;
    }

    return ApiException(
      type: type,
      code: code,
      statusCode: statusCode,
      fieldErrors: fields,
      message: message.isNotEmpty
          ? message
          : 'Có lỗi xảy ra. Vui lòng thử lại.',
    );
  }
}
