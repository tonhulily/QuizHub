import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/design_system/app_colors.dart';
import 'core/design_system/app_icons.dart';
import 'core/design_system/app_theme.dart';
import 'core/design_system/design_tokens.dart';
import 'core/network/api_exception.dart';
import 'core/storage/local_storage.dart';
import 'core/widgets/app_feedback.dart';
import 'core/widgets/state_views.dart';
import 'data/repositories/user_repository.dart';
import 'dev/shared_chat_demo.dart';
import 'di/locator.dart';

/// Bản test FE dùng hai tài khoản thật của mock API trên Mac, không có bot.
/// Samsung: `flutter run -t lib/main_chat_demo.dart --dart-define=CHAT_DEMO_USER_ID=1`
/// Web: cùng lệnh với user 2. Xem docs/qa/chat_two_accounts.md.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppFeedback.configureLoading();
  runApp(const SharedChatDemoLauncher());
}

class SharedChatDemoLauncher extends StatefulWidget {
  const SharedChatDemoLauncher({super.key});
  @override
  State<SharedChatDemoLauncher> createState() => _SharedChatDemoLauncherState();
}

class _SharedChatDemoLauncherState extends State<SharedChatDemoLauncher> {
  SharedChatDemoConfig? _config;
  Object? _error;
  bool _loading = true;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    SharedChatDemoAdapter? adapter;
    try {
      final config = SharedChatDemoConfig.fromEnvironment();
      _config = config;
      final physicalPreferences = await SharedPreferences.getInstance();
      final preferences = SharedChatDemoPreferences(
        physicalPreferences,
        prefix: config.cachePrefix,
      );
      if (getIt.isRegistered<LocalStorage>()) await getIt.reset();
      adapter = SharedChatDemoAdapter(config: config, preferences: preferences);
      await setupLocator(
        tokenStorage: SharedChatDemoTokens(config.userId),
        credentialStorage: SharedChatDemoCredentials(),
        httpAdapter: adapter,
        preferences: preferences,
        apiBaseUrl: config.apiBaseUrl,
        chatWebSocketUrl: config.webSocketUrl,
        blockStorageScope: 'shared-chat-demo',
      );
      final me = await getIt<UserRepository>().getMe().timeout(
        const Duration(seconds: 10),
      );
      if (me.userId != config.userId) {
        throw const ApiException(
          type: ApiErrorType.server,
          message:
              'Máy chủ test trả về sai tài khoản. Hãy kiểm tra lại phiên demo.',
        );
      }
      if (mounted) {
        setState(() {
          _ready = true;
          _loading = false;
        });
      }
    } catch (error) {
      adapter?.close(force: true);
      if (getIt.isRegistered<LocalStorage>()) await getIt.reset();
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const QuizHubApp();
    return MaterialApp(
      title: 'QuizHub · Chat hai tài khoản',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(title: const Text('Chat hai tài khoản')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.spacingLG),
              child: _loading
                  ? LoadingView(
                      message:
                          'Đang mở phiên ${_config?.displayName ?? 'test'}…',
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          AppIcons.offline,
                          size: DesignTokens.spacing2XL,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: DesignTokens.spacingMD),
                        Text(
                          'Chưa kết nối được phiên test',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: DesignTokens.spacingSM),
                        Text(
                          _error is ApiException
                              ? (_error! as ApiException).message
                              : _error is FormatException
                              ? (_error! as FormatException).message
                              : 'Kiểm tra mock API trên Mac và kết nối USB, rồi thử lại.',
                          textAlign: TextAlign.center,
                        ),
                        if (_config != null) ...[
                          const SizedBox(height: DesignTokens.spacingSM),
                          Text(
                            'Tài khoản: ${_config!.displayName}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: DesignTokens.spacingLG),
                        FilledButton.icon(
                          onPressed: _connect,
                          icon: const Icon(AppIcons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
