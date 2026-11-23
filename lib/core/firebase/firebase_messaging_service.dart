import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:collection';

import '../../data/models/push_notification_payload.dart';
import '../router/app_navigator.dart';
import '../../features/notifications/navigation/notification_navigator.dart';
import 'firebase_messaging_gateway.dart';

class FirebaseMessagingService {
  final FirebaseMessagingGateway _messaging;

  final Future<void> Function(PushNotificationPayload payload)
  _openNotification;

  final StreamController<void> _foregroundEvents =
      StreamController<void>.broadcast();

  FirebaseMessagingService({
    FirebaseMessagingGateway? messaging,
    Future<void> Function(PushNotificationPayload payload)? openNotification,
  }) : _messaging = messaging ?? FirebaseMessagingGatewayImpl(),
       _openNotification = openNotification ?? _defaultOpenNotification;

  static Future<void> _defaultOpenNotification(
    PushNotificationPayload payload,
  ) async {
    final context = AppNavigator.context;

    if (context == null) {
      throw StateError('Navigation context is not ready');
    }

    await NotificationNavigator.openPush(context, payload);
  }

  Stream<void> get foregroundEvents => _foregroundEvents.stream;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _registeredSubscription;

  String? _currentToken;
  String? get currentToken => _currentToken;

  bool _initialized = false;
  final Queue<PushNotificationPayload> _pendingPayloads =
      Queue<PushNotificationPayload>();

  bool _navigationReady = false;
  bool _handlingPending = false;

  Future<void> markNavigationReady() async {
    _navigationReady = true;
    await handlePendingNotification();
  }

  void markNavigationNotReady() {
    _navigationReady = false;
  }

  void _handleNotificationTap(RemoteMessage message) {
    final payload = PushNotificationPayload.fromRemoteMessage(message);

    _pendingPayloads.addLast(payload);

    unawaited(handlePendingNotification());
  }

  Future<void> handlePendingNotification() async {
    if (!_navigationReady || _handlingPending) return;

    if (_pendingPayloads.isEmpty) return;

    _handlingPending = true;

    try {
      while (_navigationReady && _pendingPayloads.isNotEmpty) {
        final payload = _pendingPayloads.first;

        try {
          await _openNotification(payload);

          // Chỉ xóa notification vừa xử lý thành công.
          if (_pendingPayloads.isNotEmpty &&
              identical(_pendingPayloads.first, payload)) {
            _pendingPayloads.removeFirst();
          }
        } catch (e, stackTrace) {
          debugPrint('[FCM] Cannot open notification: $e');
          debugPrintStack(stackTrace: stackTrace);

          // Giữ notification lỗi ở đầu queue để có thể thử lại
          // khi navigation được đánh dấu sẵn sàng lần tiếp theo.
          break;
        }
      }
    } finally {
      _handlingPending = false;
    }
  }


  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _messaging.registerBackgroundHandler();

      final status = await _messaging.requestPermission();
      debugPrint('[FCM] Permission: $status');

      _registeredSubscription = _messaging.onRegistered.listen(
        (token) => _currentToken = token,
        onError: (Object error) {
          debugPrint('[FCM] Registration error: $error');
        },
      );

      await _messaging.register();

      _foregroundSubscription = _messaging.onMessage.listen(
        (_) => _foregroundEvents.add(null),
        onError: (Object error) {
          debugPrint('[FCM] Foreground error: $error');
        },
      );

      _openedSubscription = _messaging.onMessageOpenedApp.listen(
        _handleNotificationTap,
      );

      final initialMessage = await _messaging.getInitialMessage();

      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
    } catch (e, stackTrace) {
      debugPrint('[FCM] Initialization failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      await dispose();
      rethrow;
    }
  }

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
