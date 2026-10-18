import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/network/session_events.dart';
import '../core/services/device_service.dart';
import '../core/services/post_events.dart';
import '../core/services/social_events.dart';
import '../core/storage/credential_storage.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/token_storage.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/comment_repository.dart';
import '../data/repositories/feed_repository.dart';
import '../data/repositories/friend_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/reaction_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/user_search_repository.dart';

final GetIt getIt = GetIt.instance;

/// Đăng ký toàn bộ dependency. Gọi 1 lần trong `main()`.
///
/// Quy ước: module mới chỉ cần thêm `registerLazySingleton` repository của
/// mình ở khối "Repositories" - KHÔNG sửa tầng core.
Future<void> setupLocator({
  TokenStorage? tokenStorage,
  CredentialStorage? credentialStorage,
  HttpClientAdapter? httpAdapter,
}) async {
  // ---- Storage ----
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<LocalStorage>(LocalStorage(prefs));

  final tokens = tokenStorage ?? TokenStorage();
  await tokens.load();
  getIt.registerSingleton<TokenStorage>(tokens);
  getIt.registerSingleton<CredentialStorage>(
    credentialStorage ?? CredentialStorage(),
  );

  // ---- Core services ----
  getIt.registerSingleton<SessionEvents>(SessionEvents());
  getIt.registerSingleton<PostEvents>(PostEvents());
  getIt.registerSingleton<SocialEvents>(SocialEvents());
  getIt.registerLazySingleton<DeviceService>(
    () => DeviceService(getIt<LocalStorage>()),
  );
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(
      tokens: getIt<TokenStorage>(),
      events: getIt<SessionEvents>(),
      // ignore: invalid_use_of_visible_for_testing_member
      adapter: httpAdapter,
    ),
  );

  // ---- Repositories ----
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
      getIt<ApiClient>(),
      getIt<TokenStorage>(),
      getIt<LocalStorage>(),
      getIt<DeviceService>(),
      getIt<CredentialStorage>(),
    ),
  );
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepository(
      getIt<ApiClient>(),
      getIt<LocalStorage>(),
      getIt<CredentialStorage>(),
    ),
  );
  getIt.registerLazySingleton<PostRepository>(
    () => PostRepository(getIt<ApiClient>(), getIt<LocalStorage>()),
  );
  getIt.registerLazySingleton<CommentRepository>(
    () => CommentRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<ReactionRepository>(
    () => ReactionRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<MediaRepository>(
    () => MediaRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<ReportRepository>(
    () => ReportRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<FriendRepository>(
    () => FriendRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<UserSearchRepository>(
    () => UserSearchRepository(getIt<ApiClient>(), getIt<FriendRepository>()),
  );
  getIt.registerLazySingleton<FeedRepository>(
    () => FeedRepository(getIt<ApiClient>(), getIt<LocalStorage>()),
  );
}
