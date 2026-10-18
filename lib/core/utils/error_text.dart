import '../network/api_exception.dart';

/// Chuyển lỗi bất kỳ thành thông báo hiển thị cho người dùng.
String errorText(Object? error) {
  if (error is ApiException) return error.message;
  return 'Có lỗi xảy ra. Vui lòng thử lại.';
}

/// Lỗi liên quan mạng (để hiển thị màn "Lỗi kết nối" + nút thử lại).
bool isNetworkError(Object? error) =>
    error is ApiException && error.isNetworkError;
