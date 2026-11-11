import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/push_notification_payload.dart';
import '../router/app_navigator.dart';
import '../../features/notifications/navigation/notification_navigator.dart';
import '../../firebase_options.dart';

/// Handler chạy trong isolate riêng khi nhận message ở background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    '[FCM][Background] messageId=${message.messageId}, '
    'data=${message.data}',
  );
}

class FirebaseMessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _registeredSubscription;

  String? _currentToken;
  bool _initialized = false;

  String? get currentToken => _currentToken;

  PushNotificationPayload? _pendingPayload;

  bool _navigationReady = false;
  bool _handlingPending = false;
  
  /// Gọi khi ứng dụng đã xác định người dùng được phép vào Main.
  Future<void> markNavigationReady() async {
    _navigationReady = true;
    await handlePendingNotification();
  }
  
  /// Gọi khi người dùng đăng xuất hoặc chưa được phép vào Main.
  void markNavigationNotReady() {
    _navigationReady = false;
  }
  
  /// Nhận payload từ notification tap.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint(
      '[FCM][Opened] '
      'messageId=${message.messageId}, '
      'data=${message.data}',
    );
  
    _pendingPayload = PushNotificationPayload.fromRemoteMessage(message);
  
    handlePendingNotification();
  }
  
  /// Thử mở notification đang chờ.
  Future<void> handlePendingNotification() async {
    if (!_navigationReady || _handlingPending) return;
  
    final payload = _pendingPayload;
    final context = AppNavigator.context;
  
    if (payload == null || context == null) return;
  
    _handlingPending = true;
  
    try {
      // Chỉ xóa pending khi đã xử lý xong.
      await NotificationNavigator.openPush(context, payload);
      _pendingPayload = null;
    } catch (e, stackTrace) {
      debugPrint('[FCM] Cannot open notification: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _handlingPending = false;
    }
  }

  /// Khởi tạo FCM và đăng ký các listener.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        '[FCM] Permission: ${settings.authorizationStatus}',
      );

      // Lắng nghe sự kiện đăng ký FCM và nhận registration token.
      _registeredSubscription = _messaging.onRegistered.listen(
        (token) {
          _currentToken = token;
          debugPrint('[FCM] Registration token: $token');
        },
        onError: (Object error) {
          debugPrint('[FCM] Registration error: $error');
        },
      );

      // Yêu cầu Firebase đăng ký thiết bị nhận FCM.
      await _messaging.register();

      // App đang mở và nhận push.
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        (message) {
          debugPrint(
            '[FCM][Foreground] '
            'title=${message.notification?.title}, '
            'body=${message.notification?.body}, '
            'data=${message.data}',
          );
        },
        onError: (Object error) {
          debugPrint('[FCM] Foreground error: $error');
        },
      );

      // Người dùng nhấn notification khi app đang ở background.
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleNotificationTap,
      );

      // Người dùng nhấn notification để mở app từ trạng thái terminated.
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      debugPrint('[FCM] Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[FCM] Initialization failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      await _foregroundSubscription?.cancel();
      await _openedSubscription?.cancel();
      await _registeredSubscription?.cancel();

      _foregroundSubscription = null;
      _openedSubscription = null;
      _registeredSubscription = null;

      rethrow;

    }
  }

//  void _handleNotificationTap(RemoteMessage message) {
//    debugPrint(
//      '[FCM][Opened] '
//      'messageId=${message.messageId}, '
//      'data=${message.data}',
//    );
//
//    // Sẽ nối với NotificationNavigator sau khi thống nhất
//    // cấu trúc payload push từ backend.
//  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _registeredSubscription?.cancel();

    _foregroundSubscription = null;
    _openedSubscription = null;
    _registeredSubscription = null;

    _initialized = false;
  }
}
