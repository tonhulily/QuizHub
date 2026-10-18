import 'package:flutter/material.dart';

/// App Colors - Core Design System
///
/// TOÀN BỘ màu của app phải lấy từ file này (không hard-code màu ở nơi khác).
/// Bảng màu: đỏ HUST (primary) + vàng đồng (secondary) + neutral slate.
class AppColors {
  AppColors._();

  // Primary Colors (HUST Crimson)
  static const Color primary50 = Color(0xFFFFF1F3);
  static const Color primary100 = Color(0xFFFFE1E5);
  static const Color primary200 = Color(0xFFFFC7CF);
  static const Color primary300 = Color(0xFFFF9CAA);
  static const Color primary400 = Color(0xFFF56478);
  static const Color primary500 = Color(0xFFDF3A52);
  static const Color primary600 = Color(0xFFC41E3A); // main brand
  static const Color primary700 = Color(0xFFA31830);
  static const Color primary800 = Color(0xFF821428);
  static const Color primary900 = Color(0xFF5E0F1D);

  // Secondary Colors (Gold)
  static const Color secondary50 = Color(0xFFFFF9E8);
  static const Color secondary100 = Color(0xFFFFF0C4);
  static const Color secondary200 = Color(0xFFFFE08B);
  static const Color secondary300 = Color(0xFFFFCF52);
  static const Color secondary400 = Color(0xFFF7B52C);
  static const Color secondary500 = Color(0xFFE69B12);
  static const Color secondary600 = Color(0xFFC4800C);
  static const Color secondary700 = Color(0xFF9C6309);
  static const Color secondary800 = Color(0xFF7A4D08);
  static const Color secondary900 = Color(0xFF573706);

  // Neutral Colors (Slate)
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral200 = Color(0xFFE2E8F0);
  static const Color neutral300 = Color(0xFFCBD5E1);
  static const Color neutral400 = Color(0xFF94A3B8);
  static const Color neutral500 = Color(0xFF64748B);
  static const Color neutral600 = Color(0xFF475569);
  static const Color neutral700 = Color(0xFF334155);
  static const Color neutral800 = Color(0xFF1E293B);
  static const Color neutral900 = Color(0xFF0F172A);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF059669);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFB91C1C);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF2563EB);

  // Background Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFF0F2F5); // nền feed
  static const Color backgroundTertiary = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF0F172A);

  // Text Colors
  static const Color textPrimary = Color(0xFF050505);
  static const Color textSecondary = Color(0xFF65676B);
  static const Color textTertiary = Color(0xFF8A8D91);
  static const Color textDisabled = Color(0xFFCBD5E1);
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color textLink = Color(0xFF2563EB);

  // Border Colors
  static const Color border = Color(0xFFCED0D4);
  static const Color borderLight = Color(0xFFE4E6EB);
  static const Color borderDark = Color(0xFF94A3B8);

  // Gradients (brand)
  static const Color gradientStart = Color(0xFFE0344D);
  static const Color gradientEnd = Color(0xFF9E1530);
  static const Color goldGradientStart = Color(0xFFFFC53D);
  static const Color goldGradientEnd = Color(0xFFE69B12);
  static const Color successGradientStart = Color(0xFF34D399);
  static const Color successGradientEnd = Color(0xFF059669);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldGradientStart, goldGradientEnd],
  );

  // Overlay Colors
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white50 = Color(0x80FFFFFF);
  static const Color white20 = Color(0x33FFFFFF);

  // Social (kiểu Facebook, nhưng dùng màu thương hiệu thay cho xanh)
  /// Nền nút tròn trên header / nút phụ (xám nhạt)
  static const Color chip = Color(0xFFE4E6EB);
  static const Color like = Color(0xFFC41E3A);
  static const Color likeBackground = Color(0xFFFFF1F3);

  // Shimmer
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF8FAFC);

  /// Get color by hex string. Example: AppColors.fromHex('#FF5733')
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Convert color to hex string
  static String toHex(Color color) {
    final value = color.toARGB32();
    return '#${value.toRadixString(16).substring(2, 8).toUpperCase()}';
  }
}
