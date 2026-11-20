import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  PushNotificationPayload? _pendingPayload;

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
    _pendingPayload = PushNotificationPayload.fromRemoteMessage(message);

    unawaited(handlePendingNotification());
  }

  Future<void> handlePendingNotification() async {
    if (!_navigationReady || _handlingPending) return;

    final payload = _pendingPayload;
    if (payload == null) return;

    _handlingPending = true;
    var opened = false;

    try {
      await _openNotification(payload);
      opened = true;

      // Chỉ xóa đúng payload vừa xử lý.
      // Tránh xóa nhầm notification mới đến trong lúc đang xử lý.
      if (identical(_pendingPayload, payload)) {
        _pendingPayload = null;
      }
    } catch (e, stackTrace) {
      debugPrint('[FCM] Cannot open notification: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _handlingPending = false;
    }

    // Có lần chạm mới đến trong lúc đang mở payload trước: xử lý tiếp.
    // Nếu mở lỗi thì không lặp lại để tránh vòng lặp vô hạn.
    if (opened && _pendingPayload != null) {
      await handlePendingNotification();
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
