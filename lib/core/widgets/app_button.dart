import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import '../design_system/component_tokens.dart';
import '../design_system/design_tokens.dart';

enum AppButtonVariant { primary, secondary, outline, text, danger, neutral }

/// Nút chuẩn của app (có loading, icon, gradient thương hiệu).
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final bool expand;
  final bool small;

  /// Kiểu nút cũ (gradient thương hiệu, bo 12, cao 52) - dùng riêng cho màn
  /// Đăng nhập. Các màn còn lại dùng kiểu phẳng giống Facebook.
  final bool classic;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.small = false,
    this.classic = false,
  });

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final height = classic
        ? 52.0
        : small
        ? ComponentTokens.buttonHeightSmall
        : ComponentTokens.buttonHeight;
    final radius = BorderRadius.circular(
      classic ? DesignTokens.radiusMD : ComponentTokens.buttonRadius,
    );

    final (fg, bg, border, gradient) = switch (variant) {
      AppButtonVariant.primary => (
        AppColors.white,
        AppColors.primary600,
        null,
        classic ? AppColors.brandGradient : null,
      ),
      AppButtonVariant.neutral => (
        AppColors.textPrimary,
        AppColors.chip,
        null,
        null,
      ),
      AppButtonVariant.secondary => (
        AppColors.primary700,
        AppColors.primary50,
        null,
        null,
      ),
      AppButtonVariant.outline => (
        AppColors.primary600,
        AppColors.transparent,
        AppColors.primary600,
        null,
      ),
      AppButtonVariant.text => (
        AppColors.primary600,
        AppColors.transparent,
        null,
        null,
      ),
      AppButtonVariant.danger => (AppColors.white, AppColors.error, null, null),
    };

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 22, color: fg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: fg,
                fontSize: small ? 13 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: _enabled || loading ? 1 : DesignTokens.opacityDisabled + 0.4,
      child: SizedBox(
        height: height,
        width: expand ? double.infinity : null,
        child: Material(
          color: AppColors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? bg : null,
              borderRadius: radius,
              border: border == null ? null : Border.all(color: border),
              boxShadow:
                  variant == AppButtonVariant.primary && _enabled && !small
                  ? DesignTokens.shadowBrand
                  : null,
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: _enabled ? onPressed : null,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: small ? 16 : 24),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
