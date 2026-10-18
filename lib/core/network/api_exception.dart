import 'package:equatable/equatable.dart';

/// Loại lỗi để UI quyết định cách hiển thị.
enum ApiErrorType {
  /// Không có mạng / mất kết nối / DNS
  noConnection,

  /// Hết thời gian chờ
  timeout,

  /// Phiên đăng nhập hết hạn (refresh thất bại)
  unauthorized,

  /// Không có quyền
  forbidden,

  /// Không tìm thấy
  notFound,

  /// Dữ liệu gửi lên không hợp lệ (1002/1003/1004...)
  validation,

  /// Lỗi nghiệp vụ do backend trả về (code != success)
  business,

  /// Server lỗi (5xx) hoặc response sai định dạng
  server,

  /// Lỗi khác
  unknown,
}

/// Exception thống nhất cho toàn bộ tầng gọi API.
class ApiException extends Equatable implements Exception {
  final ApiErrorType type;
  final String message;
  final String? code;
  final int? statusCode;

  /// Lỗi chi tiết theo field (vd 1002): `{field: message}`
  final Map<String, String> fieldErrors;

  const ApiException({
    required this.type,
    required this.message,
    this.code,
    this.statusCode,
    this.fieldErrors = const {},
  });

  bool get isNetworkError =>
      type == ApiErrorType.noConnection || type == ApiErrorType.timeout;

  bool get isUnauthorized => type == ApiErrorType.unauthorized;

  /// Hết dữ liệu (code 9994) - không phải lỗi thực sự khi phân trang
  bool get isNoMoreData => code == '9994';

  @override
  List<Object?> get props => [type, message, code, statusCode, fieldErrors];

  @override
  String toString() => 'ApiException($type, code: $code, $message)';
}
