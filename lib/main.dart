import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/widgets/app_feedback.dart';
import 'di/locator.dart';

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

  await setupLocator();
  AppFeedback.configureLoading();

  runApp(const QuizHubApp());
}
