import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'response_codes.dart';
import 'session_events.dart';

/// Gắn Bearer token và tự động refresh khi access token hết hạn.
///
/// - Nhiều request cùng lỗi 401 sẽ chỉ gọi refresh 1 lần ([_refreshing]).
/// - Refresh thành công -> retry request gốc đúng 1 lần.
/// - Refresh thất bại do token không hợp lệ -> xoá token + phát
///   [SessionEvents.notifySessionExpired] (app quay về màn Login).
/// - Refresh thất bại do mất mạng -> KHÔNG đăng xuất, trả lỗi mạng.
class AuthInterceptor extends Interceptor {
  static const _retriedKey = 'auth_retried';

  final Dio _dio; // dio chính, dùng để retry
  final Dio _refreshDio; // dio sạch (không interceptor) để gọi refresh
  final TokenStorage _tokens;
  final SessionEvents _events;

  Future<bool>? _refreshing;

  AuthInterceptor({
    required Dio dio,
    required Dio refreshDio,
    required TokenStorage tokens,
    required SessionEvents events,
  }) : _dio = dio,
       _refreshDio = refreshDio,
       _tokens = tokens,
       _events = events;

  bool _isPublic(RequestOptions o) =>
      ApiEndpoints.publicPaths.any((p) => o.path.endsWith(p));

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isPublic(options)) {
      final token = _tokens.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isAuthFailure =
        err.response?.statusCode == 401 || _bodyCode(err) == '9998';

    if (!isAuthFailure ||
        _isPublic(options) ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    // Chưa từng đăng nhập (không có refresh token) -> không thể refresh
    if (!_tokens.hasTokens) {
      return handler.next(err);
    }

    final result = await _refreshOnce();
    switch (result) {
      case _RefreshResult.success:
        try {
          options.extra[_retriedKey] = true;
          options.headers['Authorization'] = 'Bearer ${_tokens.accessToken}';
          final response = await _dio.fetch<dynamic>(options);
          return handler.resolve(response);
        } on DioException catch (e) {
          return handler.next(e);
        }
      case _RefreshResult.networkError:
        return handler.next(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: err.error,
          ),
        );
      case _RefreshResult.invalid:
        return handler.next(
          DioException(
            requestOptions: options,
            response: err.response,
            type: DioExceptionType.badResponse,
            error: const ApiException(
              type: ApiErrorType.unauthorized,
              message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
              code: ResponseCodes.tokenInvalidOrExpired,
              statusCode: 401,
            ),
          ),
        );
    }
  }

  Future<_RefreshResult> _refreshOnce() async {
    final inflight = _refreshing;
    if (inflight != null) {
      final ok = await inflight;
      return ok ? _RefreshResult.success : _RefreshResult.invalid;
    }

    final completer = Completer<bool>();
    _refreshing = completer.future;
    var result = _RefreshResult.invalid;
    try {
      final res = await _refreshDio.post<dynamic>(
        ApiEndpoints.refresh,
        data: {'refresh_token': _tokens.refreshToken},
      );
      final body = res.data;
      final data = body is Map ? body['data'] : null;
      final code = body is Map ? body['code']?.toString() : null;
      if (ResponseCodes.isSuccess(code) && data is Map) {
        final access = data['access_token']?.toString();
        final refresh = data['refresh_token']?.toString();
        if (access != null && access.isNotEmpty) {
          await _tokens.save(
            accessToken: access,
            refreshToken: (refresh != null && refresh.isNotEmpty)
                ? refresh
                : _tokens.refreshToken!,
          );
          result = _RefreshResult.success;
        }
      }
    } on DioException catch (e) {
      final isNetwork =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      result = isNetwork ? _RefreshResult.networkError : _RefreshResult.invalid;
    } catch (_) {
      result = _RefreshResult.invalid;
    }

    if (result == _RefreshResult.invalid) {
      await _tokens.clear();
      _events.notifySessionExpired();
    }
    completer.complete(result == _RefreshResult.success);
    _refreshing = null;
    return result;
  }

  String? _bodyCode(DioException err) {
    final data = err.response?.data;
    return data is Map ? data['code']?.toString() : null;
  }
}

enum _RefreshResult { success, invalid, networkError }
