import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/cursor_page.dart';
import '../models/game_models.dart';

/// Minigame dự đoán + bảng xếp hạng (Swagger mục 21 "Gamification &
/// Minigames"). Mọi API đặt cược trả `GamePredictionResponse`.
///
/// Lỗi nghiệp vụ hay gặp (UI hiện nguyên `message` của server):
/// - Game 1: 409 sau 22:00 hoặc đã cược lớp này cho ngày mai; 403 không học
///   lớp này.
/// - Game 2: 400 loại câu (AI / tự soạn) có số đề xuất bằng 0; 409 đã cược
///   phiên này.
/// - Game 4: 409 đã cược môn này (mỗi người MỘT lần).
class GameRepository {
  final ApiClient _api;

  GameRepository(this._api);

  /// `GET /games/prediction/game-1/classes` - lớp đang học + đã cược chưa.
  Future<List<Game1Class>> game1Classes() => _api.get<List<Game1Class>>(
    ApiEndpoints.game1Classes,
    parser: (d) => J.list(d, Game1Class.fromJson),
  );

  /// Game 1 - `POST /games/prediction/participants`: số sinh viên của lớp sẽ
  /// đề xuất câu hỏi vào ngày mai (chốt trước 22:00, sai số ±5%).
  Future<GamePrediction> predictParticipants({
    required int courseClassId,
    required int predictedCount,
  }) {
    assert(predictedCount >= 1, 'predicted_count tối thiểu là 1');
    return _api.post<GamePrediction>(
      ApiEndpoints.predictParticipants,
      body: {
        'course_class_id': courseClassId,
        'predicted_count': predictedCount,
      },
      parser: _prediction,
    );
  }

  /// Game 2 - `POST /games/prediction/approved-questions`: số câu AI / tự
  /// soạn trong phiên của mình sẽ được giảng viên duyệt.
  Future<GamePrediction> predictApprovedQuestions({
    required int sessionId,
    int? llmCount,
    int? humanCount,
  }) => _api.post<GamePrediction>(
    ApiEndpoints.predictApprovedQuestions,
    body: {
      'session_id': sessionId,
      'predicted_llm_count': ?llmCount,
      'predicted_human_count': ?humanCount,
    },
    parser: _prediction,
  );

  /// Game 4 - `POST /games/prediction/bank-size`: tổng số câu được duyệt vào
  /// ngân hàng đề của môn khi kết thúc học kỳ. Top 3 đoán sát nhất và sớm
  /// nhất được thưởng.
  Future<GamePrediction> predictBankSize({
    required int subjectId,
    required int predictedBankSize,
  }) {
    assert(predictedBankSize >= 0, 'predicted_bank_size không được âm');
    return _api.post<GamePrediction>(
      ApiEndpoints.predictBankSize,
      body: {'subject_id': subjectId, 'predicted_bank_size': predictedBankSize},
      parser: _prediction,
    );
  }

  /// `GET /games/my-predictions` - lịch sử lượt dự đoán (mới nhất trước).
  Future<CursorPage<GamePrediction>> myPredictions({
    String? after,
    int limit = 20,
  }) => _api.get<CursorPage<GamePrediction>>(
    ApiEndpoints.myPredictions,
    query: {'after': after, 'limit': limit},
    parser: GamePrediction.pageFromJson,
  );

  /// `GET /games/leaderboard` - [subjectId] bắt buộc khi
  /// [period] = [LeaderboardPeriod.subject].
  Future<Leaderboard> leaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.semester,
    int? subjectId,
    int limit = 50,
  }) => _api.get<Leaderboard>(
    ApiEndpoints.leaderboard,
    query: {
      'period': period.apiValue,
      if (period == LeaderboardPeriod.subject) 'subject_id': subjectId,
      'limit': limit,
    },
    parser: (d) => Leaderboard.fromJson(J.asMap(d) ?? const {}),
  );

  static GamePrediction _prediction(dynamic d) =>
      GamePrediction.fromJson(J.asMap(d) ?? const {});
}
