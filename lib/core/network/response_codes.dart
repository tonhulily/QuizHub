/// Mã `code` trong body response của backend.
///
/// Slide mô tả 1000 = SUCCESS, Swagger mô tả 0000 -> chấp nhận cả hai.
/// Muốn đổi quy ước thành công chỉ cần sửa [isSuccess].
class ResponseCodes {
  ResponseCodes._();

  static const String success = '0000';
  static const String successLegacy = '1000';

  static const String databaseError = '1001';
  static const String missingParameter = '1002';
  static const String invalidParameterType = '1003';
  static const String invalidParameterValue = '1004';
  static const String unknownSystemError = '1005';
  static const String fileSizeExceeded = '1006';
  static const String fileUploadFailed = '1007';
  static const String mediaLimitExceeded = '1008';
  static const String accessDenied = '1009';
  static const String actionAlreadyPerformed = '1010';
  static const String contentViolatesPolicy = '1011';
  static const String resourceNotFound = '1012';

  static const String userNotVerified = '9992';
  static const String verificationCodeInvalid = '9993';
  static const String noMoreData = '9994';
  static const String userNotExists = '9995';
  static const String userAlreadyExists = '9996';
  static const String methodNotAllowed = '9997';
  static const String tokenInvalidOrExpired = '9998';
  static const String unhandledException = '9999';

  /// Sai tài khoản / mật khẩu (thực tế backend trả 9990)
  static const String wrongCredentials = '9990';

  static bool isSuccess(String? code) {
    if (code == null || code.isEmpty) return false;
    return code == success ||
        code == successLegacy ||
        code == '200' ||
        RegExp(r'^0+$').hasMatch(code);
  }
}
