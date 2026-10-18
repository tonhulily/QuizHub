import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';

/// Logo QuizHub (vẽ bằng icon + gradient vàng, không cần asset).
class BrandLogo extends StatelessWidget {
  final double size;
  final bool onDark;

  const BrandLogo({super.key, this.size = 56, this.onDark = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDark ? AppColors.white : null,
        gradient: onDark ? null : AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            AppIcons.quizActive,
            size: size * 0.58,
            color: onDark ? AppColors.primary600 : AppColors.white,
          ),
          Positioned(
            right: size * 0.14,
            top: size * 0.14,
            child: Container(
              width: size * 0.2,
              height: size * 0.2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.goldGradient,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
