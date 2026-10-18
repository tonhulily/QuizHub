import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../di/locator.dart';
import '../../../core/design_system/app_icons.dart';

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _saving = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_oldCtrl.text == _newCtrl.text) {
      AppFeedback.errorMessage(
        context,
        'Mật khẩu mới phải khác mật khẩu hiện tại.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await getIt<AuthRepository>().changePassword(
        oldPassword: _oldCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      final nav = Navigator.of(context);
      AppFeedback.success(context, 'Đổi mật khẩu thành công');
      nav.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(DesignTokens.spacingLG),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.secondary50,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                    border: Border.all(color: AppColors.secondary200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        AppIcons.shield,
                        color: AppColors.secondary700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mật khẩu mới gồm ${Validators.passwordMinLength}-${Validators.passwordMaxLength} '
                          'ký tự, chỉ chứa chữ và số (không có ký tự đặc biệt).',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondary900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _oldCtrl,
                  label: 'Mật khẩu hiện tại',
                  prefixIcon: AppIcons.lock,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  validator: Validators.loginPassword,
                  onSubmitted: (_) => _newFocus.requestFocus(),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _newCtrl,
                  focusNode: _newFocus,
                  label: 'Mật khẩu mới',
                  prefixIcon: AppIcons.passwordReset,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  validator: Validators.newPassword,
                  onSubmitted: (_) => _confirmFocus.requestFocus(),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirmCtrl,
                  focusNode: _confirmFocus,
                  label: 'Nhập lại mật khẩu mới',
                  prefixIcon: AppIcons.shieldCheck,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      Validators.confirmPassword(v, _newCtrl.text),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: 'Cập nhật mật khẩu',
                  loading: _saving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
