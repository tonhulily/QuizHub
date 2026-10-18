import 'package:flutter/material.dart';

import 'app.dart';
import 'core/storage/credential_storage.dart';
import 'core/widgets/app_feedback.dart';
import 'data/models/saved_account.dart';
import 'dev/preview_backend.dart';
import 'di/locator.dart';

/// Chạy app với DỮ LIỆU MẪU (không cần tài khoản / backend) để xem và phát
/// triển giao diện:
///
/// ```
/// flutter run -t lib/main_preview.dart
/// # kèm sẵn một "tài khoản đã lưu" để xem thẻ đăng nhập nhanh:
/// flutter run -t lib/main_preview.dart --dart-define=SEED_SAVED_ACCOUNT=true
/// ```
///
/// Đã đăng nhập sẵn với người dùng mẫu "Nguyễn Văn An". Mọi thay đổi chỉ nằm
/// trong RAM. Bản chạy thật vẫn là `lib/main.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupLocator(
    tokenStorage: PreviewTokens(),
    httpAdapter: PreviewBackend(),
  );
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
