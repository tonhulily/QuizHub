import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/app_colors.dart';
import '../design_system/app_icons.dart';

/// TextField chuẩn: nhãn phía trên, icon, ẩn/hiện mật khẩu, validator.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? errorText;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;

  /// Kiểu ô nhập cũ (bo 12, viền xám xanh) - dùng riêng cho màn Đăng nhập.
  final bool classic;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.errorText,
    this.autofillHints,
    this.inputFormatters,
    this.autovalidateMode,
    this.classic = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  static OutlineInputBorder _classicBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          autovalidateMode: widget.autovalidateMode,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            border: widget.classic
                ? _classicBorder(AppColors.neutral200)
                : null,
            enabledBorder: widget.classic
                ? _classicBorder(AppColors.neutral200)
                : null,
            focusedBorder: widget.classic
                ? _classicBorder(AppColors.primary600, 1.6)
                : null,
            errorBorder: widget.classic
                ? _classicBorder(AppColors.error)
                : null,
            focusedErrorBorder: widget.classic
                ? _classicBorder(AppColors.error, 1.6)
                : null,
            hintText: widget.hint,
            errorText: widget.errorText,
            errorMaxLines: 3,
            counterText: widget.maxLength == null ? '' : null,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 22),
            prefixIconColor: WidgetStateColor.resolveWith(
              (s) => s.contains(WidgetState.focused)
                  ? AppColors.primary600
                  : AppColors.textTertiary,
            ),
            suffixIcon: widget.obscure
                ? IconButton(
                    splashRadius: 20,
                    icon: Icon(
                      _hidden ? AppIcons.eyeOff : AppIcons.eye,
                      size: 22,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
