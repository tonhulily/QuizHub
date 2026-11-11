import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/firebase_fid_sync_service.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/widgets/app_feedback.dart';
import 'di/locator.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Không để app crash trắng màn hình: log lỗi Flutter để dễ debug
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Uncaught] $error\n$stack');
    return true;
  };

  // Firebase là dịch vụ bổ trợ, không để lỗi Firebase chặn app.
  var firebaseInitialized = false;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
    debugPrint('[Firebase] Initialized successfully');
  } catch (error, stackTrace) {
    debugPrint('[Firebase] Initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  await setupLocator();

  // Chỉ theo dõi và đồng bộ FID nếu Firebase đã khởi tạo.
  if (firebaseInitialized) {
    await getIt<FirebaseFidSyncService>().start();
    await getIt<FirebaseMessagingService>().initialize();
  }
  AppFeedback.configureLoading();

  runApp(const QuizHubApp());
}
