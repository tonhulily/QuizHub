import 'package:flutter/material.dart';

import 'app_routes.dart';

/// Điều hướng không cần BuildContext (vd khi phiên hết hạn từ tầng network).
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static NavigatorState? get _nav => key.currentState;

  static BuildContext? get context => key.currentContext;

  /// Xoá toàn bộ stack và về màn Login.
  static void toLogin() {
    _nav?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  /// Xoá toàn bộ stack và vào màn chính.
  static void toMain() {
    _nav?.pushNamedAndRemoveUntil(AppRoutes.main, (_) => false);
  }
}
