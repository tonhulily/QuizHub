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
  static const followers = '/relationships/followers';
  static const following = '/relationships/following';
  static const blockedUsers = '/relationships/blocked';

  static const conversations = '/chat';
  static const chatDetail = '/chat/detail'; // arguments: ChatTarget

  // Ngân hàng câu hỏi
  static const qbankMySubmissions = '/qbank/my-submissions';
  // arguments: int sessionId, hoặc ({int id, SessionStatus status})
  static const qbankSubmission = '/qbank/submission';
  // arguments: SubmissionDetail? (null = tạo mới); pop -> true nếu đã lưu
  static const qbankSubmissionForm = '/qbank/submission/form';
  // arguments: int sessionId, hoặc ({int sessionId, int questionId}) để mở
  // thẳng một câu
  static const qbankPractice = '/qbank/practice';
  // arguments: ({int questionId, List<String> correctKeys})
  static const qbankQuestionStats = '/qbank/question/stats';
  // arguments: AiRefineArgs; pop -> true nếu đã lưu bản AI
  static const qbankAiRefine = '/qbank/ai-refine';

  // Minigame dự đoán + bảng xếp hạng (Swagger mục 21)
  static const minigameHub = '/games';
  static const minigameParticipants = '/games/participants'; // Game 1
  static const minigameApprovedQuestions = '/games/approved-questions'; // G2
  static const minigameBankSize = '/games/bank-size'; // Game 4
  static const minigamePredictions = '/games/my-predictions';
  static const leaderboard = '/games/leaderboard';

  // Đề thi (chỉ giảng viên)
  static const examMyExams = '/exam/my-exams';
  static const examGenerator = '/exam/generate';
  // arguments: int examId, hoặc ExamDetail (đề vừa sinh -> màn xem trước)
  static const examDetail = '/exam/detail';

  // Social (module khác sẽ bổ sung)
  static const postDetail = '/post/detail'; // arguments: int postId
  static const createPost = '/post/create'; // pop -> PostModel? (bài vừa đăng)
  static const editPost =
      '/post/edit'; // arguments: PostModel; pop -> PostModel?
}
