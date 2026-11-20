import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:quizhub/core/firebase/firebase_messaging_gateway.dart';

class FakeFirebaseMessagingGateway
    implements FirebaseMessagingGateway {
  final foregroundController =
      StreamController<RemoteMessage>.broadcast();

  final openedController =
      StreamController<RemoteMessage>.broadcast();

  final registeredController =
      StreamController<String>.broadcast();

  @override
  Stream<RemoteMessage> get onMessage =>
      foregroundController.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      openedController.stream;

  @override
  Stream<String> get onRegistered =>
      registeredController.stream;

  AuthorizationStatus permissionStatus =
      AuthorizationStatus.authorized;

  RemoteMessage? initialMessage;

  int backgroundHandlerRegistrations = 0;
  int permissionRequests = 0;
  int registerCalls = 0;
  int initialMessageCalls = 0;

  bool shouldFailRegister = false;

  @override
  Future<AuthorizationStatus> requestPermission() async {
    permissionRequests++;
    return permissionStatus;
  }

  @override
  Future<void> register() async {
    registerCalls++;

    if (shouldFailRegister) {
      throw Exception('Register failed');
    }
  }

  @override
  Future<RemoteMessage?> getInitialMessage() async {
    initialMessageCalls++;
    return initialMessage;
  }

  @override
  void registerBackgroundHandler() {
    backgroundHandlerRegistrations++;
  }

  Future<void> close() async {
    await foregroundController.close();
    await openedController.close();
    await registeredController.close();
  }
}
