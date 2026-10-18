import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/router/app_navigator.dart';
import '../../core/router/app_routes.dart';
import '../auth/cubit/auth_cubit.dart';
import '../auth/widgets/brand_logo.dart';
import '../profile/cubit/profile_cubit.dart';

/// Màn hình khởi động: quyết định vào Login hay Main.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _anim,
    curve: Curves.elasticOut,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _anim,
    curve: const Interval(0.4, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final auth = context.read<AuthCubit>();
    final profile = context.read<ProfileCubit>();

    auth.bootstrap();
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 1400));

    if (auth.state.status == AuthStatus.authenticated) {
      // Xác thực token bằng cách lấy hồ sơ (cache hiển thị ngay nếu có).
      // Lỗi mạng KHÔNG đẩy người dùng ra Login - họ vẫn dùng được bằng cache.
      await Future.wait([
        minDelay,
        profile
            .load(silent: true)
            .timeout(const Duration(seconds: 6), onTimeout: () {}),
      ]);
    } else {
      await minDelay;
    }

    if (!mounted) return;
    // Có thể đã bị đá ra Login nếu refresh token hết hạn trong lúc chờ
    if (auth.state.status != AuthStatus.authenticated) {
      AppNavigator.toLogin();
      return;
    }

    final me = profile.state.profile;
    if (me != null && !me.profileCompleted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.editProfile,
        (_) => false,
        arguments: true,
      );
    } else {
      AppNavigator.toMain();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 5),
              ScaleTransition(scale: _scale, child: const BrandLogo(size: 96)),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Text(
                      'QuizHub',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppColors.white,
                        fontSize: 38,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mạng xã hội ngân hàng đề Bách Khoa',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 4),
              FadeTransition(
                opacity: _fade,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'HUST · ONE LOVE ONE FUTURE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.white50,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
