import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../design_system/app_colors.dart';
import '../design_system/component_tokens.dart';
import '../design_system/design_tokens.dart';
import '../utils/error_text.dart';
import '../design_system/app_icons.dart';

/// Snackbar / loading overlay / dialog dùng chung.
class AppFeedback {
  AppFeedback._();

  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.successDark, AppIcons.success);

  static void error(BuildContext context, Object? error) =>
      _show(context, errorText(error), AppColors.error, AppIcons.error);

  static void errorMessage(BuildContext context, String message) =>
      _show(context, message, AppColors.error, AppIcons.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.neutral800, AppIcons.info);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          margin: const EdgeInsets.all(DesignTokens.spacingMD),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ComponentTokens.snackbarRadius),
          ),
          content: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// Overlay loading toàn màn hình (EasyLoading).
  static Future<void> showLoading([String? status]) =>
      EasyLoading.show(status: status, maskType: EasyLoadingMaskType.black);

  static Future<void> hideLoading() => EasyLoading.dismiss();

  /// Chạy [task] có overlay loading, tự ẩn kể cả khi lỗi.
  static Future<T> withLoading<T>(Future<T> Function() task) async {
    await showLoading();
    try {
      return await task();
    } finally {
      await hideLoading();
    }
  }

  /// Cấu hình EasyLoading theo theme app. Gọi 1 lần ở `main()`.
  static void configureLoading() {
    EasyLoading.instance
      ..displayDuration = const Duration(seconds: 2)
      ..indicatorType = EasyLoadingIndicatorType.fadingCircle
      ..loadingStyle = EasyLoadingStyle.custom
      ..indicatorSize = 40
      ..radius = DesignTokens.radiusLG
      ..backgroundColor = AppColors.white
      ..indicatorColor = AppColors.primary600
      ..textColor = AppColors.textPrimary
      ..maskColor = AppColors.overlayLight
      ..userInteractions = false
      ..dismissOnTap = false;
  }
}

/// Hộp thoại xác nhận chuẩn. Trả về `true` nếu người dùng đồng ý.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Đồng ý',
  String cancelLabel = 'Huỷ',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: destructive
                ? AppColors.error
                : AppColors.primary600,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
