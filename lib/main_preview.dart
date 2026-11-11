import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/storage/credential_storage.dart';
import 'core/widgets/app_feedback.dart';
import 'data/models/saved_account.dart';
import 'dev/preview_backend.dart';
import 'di/locator.dart';
import 'firebase_options.dart';

/// Chạy app với DỮ LIỆU MẪU (không cần tài khoản / backend) để xem và phát
/// triển giao diện:
///
/// ```
/// flutter run -t lib/main_preview.dart
/// # kèm sẵn một "tài khoản đã lưu" để xem thẻ đăng nhập nhanh:
/// flutter run -t lib/main_preview.dart --dart-define=SEED_SAVED_ACCOUNT=true
/// ```
///
/// Đã đăng nhập sẵn với người dùng mẫu "Nguyễn Văn An". Bài viết, reaction
/// bình luận, quan hệ xã hội và lịch sử chat được lưu trên máy; dữ liệu khác trong RAM.
/// Chat ở bản này chỉ lưu trên từng thiết bị, không có bot. Test hai tài khoản dùng
/// `lib/main_chat_demo.dart` cùng mock API trên Mac.
/// Bản thật là `lib/main.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase là dịch vụ bổ trợ, không để lỗi Firebase chặn app khởi động.
  var firebaseInitialized = false;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
  } catch (error, stackTrace) {
    debugPrint('[Firebase] Initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  final preferences = await SharedPreferences.getInstance();
  final backend = PreviewBackend(preferences: preferences);
  await setupLocator(
    tokenStorage: PreviewTokens(),
    httpAdapter: backend,
    chatRealtime: backend.chat.realtime,
    blockStorageScope: 'preview',
  );
  if (firebaseInitialized) {
    // Chỉ khởi tạo FCM client, không đồng bộ FID với backend thật.
    await getIt<FirebaseMessagingService>().initialize();
  }
  AppFeedback.configureLoading();

  if (const bool.fromEnvironment('SEED_SAVED_ACCOUNT')) {
    await getIt<CredentialStorage>().save(
      const SavedAccount(
        email: 'an.nv210001@sis.hust.edu.vn',
        password: 'Abc@12345',
        fullName: 'Nguyễn Văn An',
        avatarUrl: 'https://i.pravatar.cc/300?img=12',
      ),
    );
  }

  runApp(const QuizHubApp());
}
