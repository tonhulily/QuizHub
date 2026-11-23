import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_messaging_background_handler.dart';

abstract interface class FirebaseMessagingGateway {
  Stream<RemoteMessage> get onMessage;

  Stream<RemoteMessage> get onMessageOpenedApp;

  Stream<String> get onRegistered;

  Future<AuthorizationStatus> requestPermission();

  Future<void> register();

  Future<RemoteMessage?> getInitialMessage();

  void registerBackgroundHandler();
}

class FirebaseMessagingGatewayImpl implements FirebaseMessagingGateway {
  final FirebaseMessaging _messaging;

  FirebaseMessagingGatewayImpl({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Stream<String> get onRegistered => _messaging.onRegistered;

  @override
  Future<AuthorizationStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus;
  }

  @override
  Future<void> register() => _messaging.register();

  @override
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  @override
  void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
}
