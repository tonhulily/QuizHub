import 'design_tokens.dart';

/// Component Tokens - kích thước chuẩn cho từng component dùng chung.
class ComponentTokens {
  ComponentTokens._();

  // Button
  static const double buttonHeight = 44.0;
  static const double buttonHeightSmall = 36.0;
  static const double buttonRadius = DesignTokens.radiusSM;

  // Input
  static const double inputRadius = DesignTokens.radiusSM;
  static const double inputHeight = 52.0;

  // Header / Tab (Facebook-style)
  static const double circleButton = 36.0;

  /// Khoảng xám giữa các bài viết trong feed
  static const double postGap = 8.0;

  // Card
  static const double cardRadius = DesignTokens.radiusMD;
  static const double cardPadding = DesignTokens.spacingMD;

  // Avatar
  static const double avatarXS = 24.0;
  static const double avatarSM = 32.0;
  static const double avatarMD = 40.0;
  static const double avatarLG = 64.0;
  static const double avatarXL = 96.0;

  /// Avatar trang cá nhân (đè lên ảnh bìa)
  static const double avatarProfile = 120.0;

  // Bottom sheet
  static const double bottomSheetRadius = DesignTokens.radiusXL;
  static const double bottomSheetPadding = DesignTokens.spacingLG;

  // Snackbar
  static const double snackbarRadius = DesignTokens.radiusMD;

  // Post
  static const int postCollapsedLines = 5;
  static const int maxImagesPerPost = 4;
  static const int maxPostWords = 500;
  static const int maxCommentWords = 500;
  static const int maxImageSizeBytes = 4 * 1024 * 1024;
}
