import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/models/notification_models.dart';

/// Chuyển notification target (hoặc target.url do backend cung cấp)
/// thành route native của Flutter.
///
/// URL chỉ được dùng như một chỉ dẫn nội bộ: không mở URL tuỳ ý từ API.
class NotificationNavigator {
  NotificationNavigator._();

  static Future<bool> open(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final target = notification.target;

    // Frontend web ưu tiên target.url. Flutter giữ cùng quy tắc này,
    // nhưng chuyển các URL nội bộ sang named route tương ứng.
    final fromUrl = _routeFromUrl(target?.url);
    if (fromUrl != null) {
      await Navigator.of(context).pushNamed(
        fromUrl.route,
        arguments: fromUrl.arguments,
      );
      return true;
    }

    final id = target?.targetId;
    switch (notification.type) {
      case 'FRIEND_REQUEST':
        // Với lời mời kết bạn, actor là người gửi lời mời.
        final actorId = notification.actor?.userId ?? id;
        if (actorId == null || actorId <= 0) return _unsupported(context);
        await Navigator.of(context).pushNamed(
          AppRoutes.userProfile,
          arguments: actorId,
        );
        return true;

      case 'NEW_COMMENT':
      case 'LEADERBOARD_HONOR':
        if (id == null || id <= 0) return _unsupported(context);
        await Navigator.of(context).pushNamed(
          AppRoutes.postDetail,
          arguments: id,
        );
        return true;

      case 'QUESTION_APPROVED':
        if (id == null || id <= 0) return _unsupported(context);
        await Navigator.of(context).pushNamed(
          AppRoutes.qbankSubmission,
          arguments: id,
        );
        return true;

      case 'QUESTION_ERROR_PENALTY':
        if (id == null || id <= 0) return _unsupported(context);
        // Backend không có api lấy thông tin session từ questionId, 
        // nên mở tab My Submissions để người dùng tự tìm session liên quan.
        await Navigator.of(context).pushNamed(
          AppRoutes.qbankMySubmissions
        );
        return true;

      case 'GAME5_SEMESTER_RECAP':
        // Backend đặt target USER; theo fallback của web, mở hồ sơ user.
        if (id == null || id <= 0) return _unsupported(context);
        await Navigator.of(context).pushNamed(
          AppRoutes.userProfile,
          arguments: id,
        );
        return true;

      case 'EARNED_BADGE':
        // Chưa có tab BADGE trong ứng dụng; không điều hướng sai đích.
        return _unsupported(context, 'Mục Huy hiệu chưa được triển khai.');

      default:
        switch (target?.type.toUpperCase()) {
          case 'POST':
            if (id == null || id <= 0) return _unsupported(context);
            await Navigator.of(context).pushNamed(
              AppRoutes.postDetail,
              arguments: id,
            );
            return true;
          case 'SESSION':
            if (id == null || id <= 0) return _unsupported(context);
            await Navigator.of(context).pushNamed(
              AppRoutes.qbankSubmission,
              arguments: id,
            );
            return true;
          case 'QUESTION':
            if (id == null || id <= 0) return _unsupported(context);
            await Navigator.of(context).pushNamed(
              AppRoutes.qbankMySubmissions,
            );
            return true;
          case 'USER':
            if (id == null || id <= 0) return _unsupported(context);
            await Navigator.of(context).pushNamed(
              AppRoutes.userProfile,
              arguments: id,
            );
            return true;
          case 'CONVERSATION':
            if (id == null || id <= 0) return _unsupported(context);
            await Navigator.of(context).pushNamed(
              AppRoutes.chatDetail,
              arguments: ChatTarget.conversation(
                ChatConversation(
                  conversationId: id,
                  title: 'Cuộc trò chuyện',
                ),
              ),
            );
            return true;
          case 'BADGE':
            return _unsupported(context, 'Mục Huy hiệu chưa được triển khai.');
          default:
            return _unsupported(context);
        }
    }
  }

  static _NotificationRoute? _routeFromUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;

    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return null;

    // Chấp nhận relative URL hoặc URL cùng host API/web; không mở host lạ.
    if (uri.hasScheme &&
        uri.host.isNotEmpty &&
        !{
          'snsqb.duckdns.org',
          'localhost',
          '127.0.0.1',
        }.contains(uri.host.toLowerCase())) {
      return null;
    }

    final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;

    int? pathId(int index) {
      if (parts.length <= index) return null;
      return int.tryParse(parts[index]);
    }

    switch (parts.first.toLowerCase()) {
      case 'posts':
        final id = pathId(1);
        return id != null && id > 0
            ? _NotificationRoute(AppRoutes.postDetail, id)
            : null;
      case 'sessions':
        final id = pathId(1);
        if (id != null && id > 0) {
          return _NotificationRoute(AppRoutes.qbankSubmission, id);
        }
        // URL /sessions?questionId=... của frontend web.
        final questionId = int.tryParse(uri.queryParameters['questionId'] ?? '');
        return questionId != null && questionId > 0
            ? _NotificationRoute(
                AppRoutes.searchGlobal,
                '$questionId',
              )
            : null;
      case 'questions':
        final id = pathId(1);
        return id != null && id > 0
            ? _NotificationRoute(AppRoutes.searchGlobal, '$id')
            : null;
      case 'users':
        final id = pathId(1);
        return id != null && id > 0
            ? _NotificationRoute(AppRoutes.userProfile, id)
            : null;
      case 'messages':
      case 'conversations':
        final id = pathId(1);
        return id != null && id > 0
            ? _NotificationRoute(
                AppRoutes.chatDetail,
                ChatTarget.conversation(
                  ChatConversation(
                    conversationId: id,
                    title: 'Cuộc trò chuyện',
                  ),
                ),
              )
            : null;
      case 'gamification':
        // Chưa có màn BADGE, không điều hướng tới một trang không tương ứng.
        return null;
      default:
        return null;
    }
  }

  static bool _unsupported(
    BuildContext context, [
    String message = 'Chưa thể mở nội dung của thông báo này.',
  ]) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}

class _NotificationRoute {
  final String route;
  final Object? arguments;
  const _NotificationRoute(this.route, [this.arguments]);
}
