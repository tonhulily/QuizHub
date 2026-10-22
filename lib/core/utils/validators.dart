/// Validate phía client (dùng Regex) trước khi gọi API.
///
/// Thông báo lỗi dùng chung cho mọi màn hình (Login, Đổi mật khẩu...) để
/// luôn thống nhất.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(
    r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$",
  );

  /// Mật khẩu chỉ gồm chữ + số (không ký tự đặc biệt, không khoảng trắng).
  static final RegExp _passwordChars = RegExp(r'^[A-Za-z0-9]+$');

  static const int passwordMinLength = 6;
  static const int passwordMaxLength = 32;

  static const String msgEmailRequired = 'Vui lòng nhập email.';
  static const String msgEmailInvalid = 'Email không đúng định dạng.';
  static const String msgPasswordRequired = 'Vui lòng nhập mật khẩu.';
  static const String msgPasswordSpecialChars =
      'Mật khẩu không được chứa ký tự đặc biệt hoặc khoảng trắng.';
  static const String msgPasswordLength =
      'Mật khẩu phải từ $passwordMinLength đến $passwordMaxLength ký tự.';

  static const String schoolEmailDomain = '@sis.hust.edu.vn';
  static String withSchoolDomain(String value) {
    final v = value.trim();
    if (v.isEmpty || v.contains('@')) return v;
    return '$v$schoolEmailDomain';
  }
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return msgEmailRequired;
    if (!_email.hasMatch(v)) return msgEmailInvalid;
    return null;
  }

  /// Dùng cho màn Login: chỉ cần không rỗng (tài khoản cũ có thể khác quy tắc).
  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return msgPasswordRequired;
    return null;
  }

  /// Dùng khi ĐẶT mật khẩu mới.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return msgPasswordRequired;
    if (!_passwordChars.hasMatch(v)) return msgPasswordSpecialChars;
    if (v.length < passwordMinLength || v.length > passwordMaxLength) {
      return msgPasswordLength;
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Vui lòng nhập lại mật khẩu mới.';
    if (value != original) return 'Mật khẩu nhập lại không khớp.';
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Vui lòng nhập họ và tên.';
    if (v.length > 100) return 'Họ và tên tối đa 100 ký tự.';
    return null;
  }

  static String? bio(String? value) {
    if ((value ?? '').length > 500) return 'Tiểu sử tối đa 500 ký tự.';
    return null;
  }

  /// Đếm số từ (tách theo khoảng trắng) - giới hạn bài viết/bình luận 500 từ.
  static int wordCount(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }
}
