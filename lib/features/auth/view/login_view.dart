import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_navigator.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/saved_account.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../di/locator.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/login_cubit.dart';
import '../widgets/brand_logo.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(getIt<AuthRepository>()),
      child: const _LoginBody(),
    );
  }
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _autoValidate = false;

  /// Tài khoản đã lưu trên máy (đăng nhập nhanh) và các trạng thái liên quan.
  SavedAccount? _saved;
  bool _useOther = false;
  bool _remember = true;

  /// Lần đăng nhập gần nhất - dùng để lưu / bỏ lưu tài khoản khi thành công.
  ({String email, String password, bool remember, bool fromSaved})? _attempt;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    // Thông báo khi bị đưa về Login do phiên hết hạn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthCubit>().state.sessionExpired) {
        AppFeedback.info(
          context,
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }
    });
  }

  Future<void> _loadSaved() async {
    final saved = await getIt<AuthRepository>().savedAccount();
    if (mounted && saved != null) setState(() => _saved = saved);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _autoValidate = true);
    // Validate phía client trước; chỉ khi hợp lệ mới gọi API
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _login(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      remember: _remember,
    );
  }

  /// Đăng nhập nhanh bằng tài khoản đã lưu (chỉ cần bấm).
  void _submitSaved() {
    final saved = _saved;
    if (saved == null) return;
    FocusScope.of(context).unfocus();
    _login(
      email: saved.email,
      password: saved.password,
      remember: true,
      fromSaved: true,
    );
  }

  void _login({
    required String email,
    required String password,
    required bool remember,
    bool fromSaved = false,
  }) {
    _attempt = (
      email: email.trim(),
      password: password,
      remember: remember,
      fromSaved: fromSaved,
    );
    context.read<LoginCubit>().submit(email: email, password: password);
  }

  Future<void> _forgetSaved() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Bỏ tài khoản đã lưu?',
      message: 'Lần sau bạn sẽ phải nhập lại email và mật khẩu trên máy này.',
      confirmLabel: 'Bỏ lưu',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await getIt<AuthRepository>().forgetAccount();
    if (!mounted) return;
    setState(() {
      _saved = null;
      _useOther = false;
    });
  }

  void _onState(BuildContext context, LoginState state) {
    if (state.status == LoginStatus.failure) {
      AppFeedback.error(context, state.error);
      final a = _attempt;
      final type = state.error?.type;
      final wrongCredentials =
          type == ApiErrorType.business ||
          type == ApiErrorType.validation ||
          type == ApiErrorType.unauthorized;
      if (a != null && a.fromSaved && wrongCredentials) {
        // Mật khẩu đã lưu không còn đúng (vd đã đổi ở máy khác): bỏ lưu và để
        // người dùng nhập lại, điền sẵn email.
        getIt<AuthRepository>().forgetAccount();
        setState(() {
          _saved = null;
          _useOther = false;
          _emailCtrl.text = a.email;
          _passwordCtrl.clear();
        });
      }
    } else if (state.status == LoginStatus.success) {
      final a = _attempt;
      if (a != null) {
        final repo = getIt<AuthRepository>();
        if (a.remember) {
          final same = _saved?.email.toLowerCase() == a.email.toLowerCase();
          repo.rememberAccount(
            SavedAccount(
              email: a.email,
              password: a.password,
              // Tên chính thức được cập nhật khi hồ sơ tải xong (UserRepository)
              fullName: same ? _saved?.fullName : null,
              avatarUrl: state.session?.avatarUrl,
            ),
          );
        } else {
          repo.forgetAccount();
        }
      }
      context.read<AuthCubit>().loggedIn();
      context.read<ProfileCubit>().load(silent: true);
      final needsProfile = state.session?.profileCompleted == false;
      if (needsProfile) {
        // Tài khoản mới: bắt buộc cập nhật tên + avatar trước khi dùng app
        AppNavigator.key.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.editProfile,
          (_) => false,
          arguments: true,
        );
      } else {
        AppNavigator.toMain();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return BlocListener<LoginCubit, LoginState>(
      listener: _onState,
      child: Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height),
              child: Stack(
                children: [
                  // ---- Hero ----
                  Container(
                    height: size.height * 0.42,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(40),
                      ),
                    ),
                    child: const _HeroDecoration(),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacingLG,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 28),
                          const BrandLogo(size: 64),
                          const SizedBox(height: 20),
                          Text(
                            'Chào mừng đến\nQuizHub',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppColors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cùng đóng góp & đánh giá câu hỏi\ncho ngân hàng đề Bách Khoa',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.white70,
                            ),
                          ),
                          SizedBox(height: size.height * 0.07),
                          _buildForm(theme),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              'Tài khoản do giảng viên cấp đầu kỳ.\nLiên hệ giảng viên nếu bạn quên mật khẩu.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    final saved = _saved;
    final quick = saved != null && !_useOther;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingLG),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXL),
        boxShadow: DesignTokens.shadowLG,
      ),
      child: quick ? _buildQuickLogin(theme, saved) : _buildManualForm(theme),
    );
  }

  /// Thẻ tài khoản đã lưu: bấm vào thẻ hoặc nút để đăng nhập ngay.
  Widget _buildQuickLogin(ThemeData theme, SavedAccount saved) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chào mừng trở lại', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Bấm vào tài khoản để đăng nhập nhanh',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        BlocBuilder<LoginCubit, LoginState>(
          buildWhen: (a, b) => a.isSubmitting != b.isSubmitting,
          builder: (context, state) => _SavedAccountTile(
            account: saved,
            enabled: !state.isSubmitting,
            onTap: _submitSaved,
            onForget: _forgetSaved,
          ),
        ),
        const SizedBox(height: 20),
        BlocBuilder<LoginCubit, LoginState>(
          buildWhen: (a, b) => a.isSubmitting != b.isSubmitting,
          builder: (context, state) => AppButton(
            label: 'Đăng nhập',
            loading: state.isSubmitting,
            classic: true,
            onPressed: _submitSaved,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _useOther = true),
            child: const Text('Dùng tài khoản khác'),
          ),
        ),
      ],
    );
  }

  Widget _buildManualForm(ThemeData theme) {
    return Form(
      key: _formKey,
      autovalidateMode: _autoValidate
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Đăng nhập', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Dùng email do trường cấp',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: _emailCtrl,
            label: 'Email',
            hint: 'ten.sv12345@sis.hust.edu.vn',
            prefixIcon: AppIcons.email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            validator: Validators.email,
            classic: true,
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            label: 'Mật khẩu',
            hint: 'Nhập mật khẩu',
            prefixIcon: AppIcons.lock,
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: Validators.loginPassword,
            classic: true,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _remember = !_remember),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _remember,
                      activeColor: AppColors.primary600,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lưu thông tin đăng nhập cho lần sau',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          BlocBuilder<LoginCubit, LoginState>(
            buildWhen: (a, b) => a.isSubmitting != b.isSubmitting,
            builder: (context, state) => AppButton(
              label: 'Đăng nhập',
              loading: state.isSubmitting,
              classic: true,
              onPressed: _submit,
            ),
          ),
          if (_saved != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _useOther = false),
                child: const Text('Quay lại tài khoản đã lưu'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ một tài khoản đã lưu: ảnh + tên + email, nút X để bỏ lưu.
class _SavedAccountTile extends StatelessWidget {
  final SavedAccount account;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onForget;

  const _SavedAccountTile({
    required this.account,
    required this.enabled,
    required this.onTap,
    required this.onForget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showEmail = account.displayName != account.email;
    return Material(
      color: AppColors.primary50,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              UserAvatar(
                avatarUrl: account.avatarUrl,
                name: account.displayName,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showEmail)
                      Text(
                        account.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Bỏ tài khoản đã lưu',
                icon: const Icon(AppIcons.close, size: 20),
                color: AppColors.textSecondary,
                onPressed: enabled ? onForget : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroDecoration extends StatelessWidget {
  const _HeroDecoration();

  @override
  Widget build(BuildContext context) {
    Widget circle(double d, double opacity) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white.withValues(alpha: opacity),
      ),
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      child: Stack(
        children: [
          Positioned(right: -50, top: -40, child: circle(220, 0.08)),
          Positioned(right: 40, top: 90, child: circle(70, 0.10)),
          Positioned(left: -60, bottom: -70, child: circle(200, 0.06)),
          Positioned(
            right: 30,
            bottom: 36,
            child: Icon(
              AppIcons.subject,
              size: 56,
              color: AppColors.secondary300.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
