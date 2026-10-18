/// Tên route tập trung. Thêm màn hình mới: khai báo ở đây + case trong
/// [AppRouter.onGenerateRoute].
class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const main = '/main';

  // Profile
  static const myProfile = '/profile/me';
  static const editProfile = '/profile/edit';
  static const profileAbout = '/profile/about'; // arguments: ProfileModel
  static const changePassword = '/profile/change-password';
  static const userProfile = '/profile/user'; // arguments: int userId

  // Bạn bè / tìm kiếm
  static const searchUsers = '/search/users';

  // Social (module khác sẽ bổ sung)
  static const postDetail = '/post/detail'; // arguments: int postId
  static const createPost = '/post/create'; // pop -> PostModel? (bài vừa đăng)
}
