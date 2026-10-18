import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/widgets/state_views.dart';

/// Nội dung tạm cho các tab của module chưa được xây dựng.
/// Tiêu đề do header của [MainShell] hiển thị nên ở đây chỉ có phần thân.
class PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String message;

  const PlaceholderTab({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      width: double.infinity,
      child: EmptyView(icon: icon, title: 'Sắp ra mắt', message: message),
    );
  }
}
