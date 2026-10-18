import 'package:flutter/material.dart';

/// Design Tokens - Core Design System
class DesignTokens {
  DesignTokens._();

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacing2XL = 48.0;
  static const double spacing3XL = 64.0;

  // Border Radius
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radius2XL = 32.0;
  static const double radiusFull = 9999.0;

  // Border Width
  static const double borderWidthThin = 1.0;
  static const double borderWidthMedium = 2.0;
  static const double borderWidthThick = 4.0;

  // Shadows
  static const List<BoxShadow> shadowSM = [
    BoxShadow(color: Color(0x0A0F172A), offset: Offset(0, 1), blurRadius: 2),
  ];

  static const List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Color(0x140F172A),
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> shadowLG = [
    BoxShadow(
      color: Color(0x1A0F172A),
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -4,
    ),
  ];

  static const List<BoxShadow> shadowBrand = [
    BoxShadow(
      color: Color(0x40C41E3A),
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -6,
    ),
  ];

  // Opacity
  static const double opacityDisabled = 0.38;

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);

  // Layout
  static const double screenPadding = 16.0;
  static const double bottomNavHeight = 64.0;
}
