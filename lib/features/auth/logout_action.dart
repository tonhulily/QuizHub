import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/widgets/app_feedback.dart';
import 'cubit/auth_cubit.dart';

/// Hỏi xác nhận rồi đăng xuất. AuthCubit đổi trạng thái -> `app.dart` tự xoá
/// hồ sơ và đưa về màn Login. Dùng chung cho Menu và Trang cá nhân.
Future<void> confirmAndLogout(BuildContext context) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Đăng xuất',
    message: 'Bạn có chắc muốn đăng xuất khỏi QuizHub?',
    confirmLabel: 'Đăng xuất',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  await AppFeedback.withLoading(() => context.read<AuthCubit>().logout());
}
