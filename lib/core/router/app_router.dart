import 'package:flutter/material.dart';

import '../../features/auth/view/login_view.dart';
import '../../features/friends/view/search_users_view.dart';
import '../../features/post/create_post_view.dart';
import '../../features/profile/widgets/friend_actions.dart';
import '../../features/exam/view/my_exams_view.dart';
import '../../features/question_bank/cubit/ai_refine_cubit.dart';
import '../../features/question_bank/view/ai_refine_view.dart';
import '../../features/question_bank/view/my_submissions_view.dart';
import '../../features/question_bank/view/practice_view.dart';
import '../../features/question_bank/view/question_stats_view.dart';
import '../../features/question_bank/view/submission_detail_view.dart';
import '../../features/question_bank/view/submission_form_view.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/session_models.dart';
import '../../features/profile/view/about_profile_view.dart';
import '../../features/profile/view/change_password_view.dart';
import '../../features/profile/view/edit_profile_view.dart';
import '../../features/profile/view/my_profile_view.dart';
import '../../features/profile/view/user_profile_view.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_view.dart';
import 'app_routes.dart';

/// Bảng định tuyến tập trung (named routes).
///
/// Thêm màn hình mới:
/// 1. Khai báo tên trong [AppRoutes]
/// 2. Thêm 1 `case` bên dưới
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;

    Widget page;
    switch (settings.name) {
      case AppRoutes.splash:
        page = const SplashView();
      case AppRoutes.login:
        page = const LoginView();
      case AppRoutes.main:
        page = const MainShell();
      case AppRoutes.myProfile:
        page = const MyProfileView(showBackButton: true);
      case AppRoutes.userProfile:
        page = UserProfileView(
          userId: args is int ? args : 0,
          // Nút Thêm bạn bè / Theo dõi / Chặn... trên trang cá nhân người khác
          actionsBuilder: (context, profile) => FriendActions(profile: profile),
        );
      case AppRoutes.profileAbout:
        page = args is ProfileModel
            ? AboutProfileView(profile: args)
            : _NotFoundView(name: settings.name);
      case AppRoutes.searchUsers:
        page = const SearchUsersView();
      case AppRoutes.editProfile:
        // arguments: bool forceComplete (bắt buộc hoàn thiện hồ sơ lần đầu)
        page = EditProfileView(forceComplete: args == true);
      case AppRoutes.createPost:
        page = CreatePostView(pickImagesOnOpen: args == true);
      case AppRoutes.changePassword:
        page = const ChangePasswordView();
      case AppRoutes.examMyExams:
        page = const MyExamsView();
      case AppRoutes.qbankAiRefine:
        page = args is AiRefineArgs
            ? AiRefineView(args: args)
            : _NotFoundView(name: settings.name);
      case AppRoutes.qbankMySubmissions:
        page = const MySubmissionsView();
      case AppRoutes.qbankSubmission:
        page = switch (args) {
          final int id => SubmissionDetailView(sessionId: id),
          (:final int id, :final SessionStatus status) => SubmissionDetailView(
            sessionId: id,
            statusHint: status,
          ),
          _ => _NotFoundView(name: settings.name),
        };
      case AppRoutes.qbankSubmissionForm:
        page = SubmissionFormView(
          initial: args is SubmissionDetail ? args : null,
        );
      case AppRoutes.qbankPractice:
        page = args is int
            ? PracticeView(sessionId: args)
            : _NotFoundView(name: settings.name);
      case AppRoutes.qbankQuestionStats:
        page = switch (args) {
          (:final int questionId, :final List<String> correctKeys) =>
            QuestionStatsView(questionId: questionId, correctKeys: correctKeys),
          _ => _NotFoundView(name: settings.name),
        };
      default:
        page = _NotFoundView(name: settings.name);
    }

    final fade =
        settings.name == AppRoutes.splash ||
        settings.name == AppRoutes.login ||
        settings.name == AppRoutes.main;

    if (fade) {
      return PageRouteBuilder<void>(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );
    }
    return MaterialPageRoute<dynamic>(
      settings: settings,
      fullscreenDialog: settings.name == AppRoutes.createPost,
      builder: (_) => page,
    );
  }
}

class _NotFoundView extends StatelessWidget {
  final String? name;
  const _NotFoundView({this.name});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Không tìm thấy')),
    body: Center(child: Text('Màn hình "$name" chưa được xây dựng.')),
  );
}
