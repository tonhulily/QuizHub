import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';

/// Nút tròn bán trong suốt đặt đè lên ảnh bìa.
class OverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const OverlayButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x66000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 24, color: AppColors.white),
        ),
      ),
    );
  }
}
