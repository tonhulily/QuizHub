/// Helper parse JSON "khoan dung": backend có thể trả số dưới dạng string,
/// boolean dưới dạng "true"/1, thời gian dưới dạng ISO hoặc Unix timestamp...
/// Dùng các hàm này trong mọi `fromJson` để model không bao giờ crash.
class J {
  J._();

  static int? asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static int intOr(dynamic v, [int fallback = 0]) => asInt(v) ?? fallback;

  static double? asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static bool asBool(dynamic v, [bool fallback = false]) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return fallback;
  }

  static String? asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static String stringOr(dynamic v, [String fallback = '']) =>
      asString(v) ?? fallback;

  /// ISO-8601 hoặc Unix timestamp (giây / mili-giây).
  static DateTime? asDate(dynamic v) {
    if (v == null) return null;
    if (v is num) return _fromEpoch(v.toInt());
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final asNum = int.tryParse(s);
    if (asNum != null) return _fromEpoch(asNum);
    return DateTime.tryParse(s)?.toLocal();
  }

  static DateTime _fromEpoch(int n) {
    // < 1e11 => giây, ngược lại => mili-giây
    final ms = n.abs() < 100000000000 ? n * 1000 : n;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Map<String, dynamic>? asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static List<dynamic> asList(dynamic v) => v is List ? v : const [];

  static List<T> list<T>(dynamic v, T Function(Map<String, dynamic> json) f) {
    final out = <T>[];
    for (final item in asList(v)) {
      final m = asMap(item);
      if (m != null) out.add(f(m));
    }
    return out;
  }
}
