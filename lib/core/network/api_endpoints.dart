/// Toàn bộ endpoint REST (đã nằm sau baseUrl `/api/v1`).
///
/// Nguồn: Swagger https://snsqb.duckdns.org/api/v1/swagger-ui/index.html
class ApiEndpoints {
  ApiEndpoints._();

  // ---- 01. Auth ----
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String changePassword = '/auth/change-password';

  // ---- 03. User ----
  static const String me = '/users/me';
  static String user(int id) => '/users/$id';
  static String userPosts(int id) => '/users/$id/posts';
  static String userRelationshipStats(int id) =>
      '/users/$id/relationship-stats';
  static String userSessions(int id) => '/users/$id/sessions';

  // ---- 04. Posts ----
  static const String posts = '/posts';
  static const String myPosts = '/posts/me';
  static String post(int id) => '/posts/$id';
  static String postLecturerNotes(int id) => '/posts/$id/lecturer-notes';
  static const String videoPosts = '/video-posts';

  // ---- 05. Comments / 06. Reactions ----
  static const String comments = '/comments';
  static String comment(int id) => '/comments/$id';
  static const String react = '/react';

  // ---- 07-09. Relationships ----
  static const String friendships = '/friendships';
  static const String friendRequest = '/friendships/request';
  static const String friendAccept = '/friendships/accept';
  static const String friendDecline = '/friendships/decline';
  static const String friendRequestsReceived = '/friendships/requests/received';
  static const String friendRequestsSent = '/friendships/requests/sent';
  static String unfriend(int id) => '/friendships/$id';
  static String follow(int id) => '/follows/$id';
  static const String following = '/follows/following';
  static const String followers = '/follows/followers';
  static const String blocks = '/blocks';
  static String block(int id) => '/blocks/$id';
  static const String report = '/report';

  // ---- 10-11. Chat ----
  static const String conversations = '/conversations';
  static const String conversationsDirect = '/conversations/direct';
  static String conversationMessages(int id) => '/conversations/$id/messages';
  static String message(int id) => '/messages/$id';

  // ---- 12. Notifications / Push ----
  static const String notifications = '/notifications';
  static String notificationRead(int id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';
  static const String pushSettings = '/settings/push';

  // ---- 13. Feed ----
  static const String activityFeeds = '/activity-feeds';
  static const String activityFeedsNewCount = '/activity-feeds/new-count';

  // ---- 15. Subjects ----
  static const String subjects = '/subjects';

  // ---- 17-19. Question sessions ----
  static const String sessionPropose = '/sessions/propose';
  static const String mySubmissions = '/sessions/my-submissions';
  static const String myEnrolledSubjects = '/sessions/my-enrolled-subjects';
  static const String sessionsPending = '/sessions/pending';
  static String session(int id) => '/sessions/$id';
  static String sessionQuestions(int id) => '/sessions/$id/questions';
  static String question(int id) => '/questions/$id';
  static String questionAnswer(int id) => '/questions/$id/answer';
  static String questionRate(int id) => '/questions/$id/rate';
  static String questionRatings(int id) => '/questions/$id/ratings';
  static String questionStatistics(int id) => '/questions/$id/statistics';
  static String mySubmission(int id) => '/sessions/my-submissions/$id';

  // ---- 16. Course classes (giảng viên) ----
  static const String lecturerMyClasses = '/lecturer/course-classes/my-classes';

  // ---- 20. Exams ----
  static const String examGenerate = '/exams/generate';
  static const String myExams = '/exams/my-exams';
  static String exam(int id) => '/exams/$id';
  static String examExport(int id) => '/exams/$id/export';

  // ---- 24. AI ----
  static String questionAiRefine(int id) => '/questions/$id/ai-refine';
  static String questionAiApply(int id) => '/questions/$id/ai-apply';

  // ---- 21. Gamification ----
  static const String leaderboard = '/games/leaderboard';
  static const String myPredictions = '/games/my-predictions';
  static const String checkIn = '/games/check-in';

  // ---- 22-23. Badges / Cosmetics ----
  static const String badgesMe = '/badges/me';
  static const String cosmeticsShop = '/cosmetics/shop';
  static const String cosmeticsInventory = '/cosmetics/my-inventory';

  // ---- 25. Search ----
  static const String search = '/search';
  static const String searchSaved = '/search/saved';

  // ---- 27. Media ----
  static const String mediaUpload = '/medias/upload';
  static const String mediaPresign = '/medias/presign';
  static const String mediaVerify = '/medias/verify';

  // ---- 28. Devices ----
  static const String devices = '/devices';
  static const String deviceFid = '/devices/fid';
  static const String deviceFidUnregister = '/devices/fid/unregister';
  static String deviceLogout(String deviceId) => '/devices/$deviceId/logout';

  /// Các endpoint KHÔNG gắn Bearer token và KHÔNG tự refresh khi 401.
  static const Set<String> publicPaths = {login, refresh};
}
