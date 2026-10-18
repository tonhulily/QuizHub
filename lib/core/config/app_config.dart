/// Cấu hình chung của app.
///
/// Có thể override khi build:
/// `flutter run --dart-define=API_BASE_URL=https://.../api/v1`
class AppConfig {
  AppConfig._();

  static const String appName = 'QuizHub';

  /// Base URL REST API (đã gồm prefix /api/v1)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://snsqb.duckdns.org/api/v1',
  );

  /// Endpoint WebSocket STOMP (dùng cho chat - chương 11)
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://snsqb.duckdns.org/api/v1/ws',
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 60);

  /// Số bản ghi mặc định mỗi trang (cursor pagination)
  static const int defaultPageSize = 10;
}
