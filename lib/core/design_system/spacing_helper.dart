import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Spacing Helper - tạo khoảng cách nhanh, đồng bộ với [DesignTokens].
class SpacingHelper {
  SpacingHelper._();

  // Vertical
  static const Widget vXS = SizedBox(height: DesignTokens.spacingXS);
  static const Widget vSM = SizedBox(height: DesignTokens.spacingSM);
  static const Widget vMD = SizedBox(height: DesignTokens.spacingMD);
  static const Widget vLG = SizedBox(height: DesignTokens.spacingLG);
  static const Widget vXL = SizedBox(height: DesignTokens.spacingXL);
  static const Widget v2XL = SizedBox(height: DesignTokens.spacing2XL);

  // Horizontal
  static const Widget hXS = SizedBox(width: DesignTokens.spacingXS);
  static const Widget hSM = SizedBox(width: DesignTokens.spacingSM);
  static const Widget hMD = SizedBox(width: DesignTokens.spacingMD);
  static const Widget hLG = SizedBox(width: DesignTokens.spacingLG);
  static const Widget hXL = SizedBox(width: DesignTokens.spacingXL);

  // Padding helpers
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: DesignTokens.screenPadding,
  );
  static const EdgeInsets allMD = EdgeInsets.all(DesignTokens.spacingMD);
  static const EdgeInsets allSM = EdgeInsets.all(DesignTokens.spacingSM);
  static const EdgeInsets allLG = EdgeInsets.all(DesignTokens.spacingLG);
}
