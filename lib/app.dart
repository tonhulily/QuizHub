import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'core/config/app_config.dart';
import 'core/design_system/app_theme.dart';
import 'core/network/session_events.dart';
import 'core/router/app_navigator.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/user_directory.dart';
import 'data/repositories/user_repository.dart';
import 'di/locator.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/profile/cubit/profile_cubit.dart';

class QuizHubApp extends StatelessWidget {
  const QuizHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) =>
              AuthCubit(getIt<AuthRepository>(), getIt<SessionEvents>()),
        ),
        BlocProvider<ProfileCubit>(
          create: (_) => ProfileCubit(getIt<UserRepository>()),
        ),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        // Chỉ phản ứng khi CHUYỂN từ đã đăng nhập -> chưa đăng nhập
        // (logout thủ công hoặc phiên hết hạn): xoá hồ sơ + về màn Login.
        listenWhen: (prev, curr) =>
            prev.status == AuthStatus.authenticated &&
            curr.status == AuthStatus.unauthenticated,
        listener: (context, state) {
          context.read<ProfileCubit>().clear();
          getIt<UserDirectory>().clear();
          AppNavigator.toLogin();
        },
        child: MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          navigatorKey: AppNavigator.key,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRouter.onGenerateRoute,
          builder: EasyLoading.init(
            builder: (context, child) {
              // Không cho hệ thống phóng chữ quá lớn làm vỡ layout
              final scaler = MediaQuery.textScalerOf(
                context,
              ).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2);
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: scaler),
                child: child ?? const SizedBox.shrink(),
              );
            },
          ),
        ),
      ),
    );
  }
}
