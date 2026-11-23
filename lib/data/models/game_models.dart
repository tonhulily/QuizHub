import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'cursor_page.dart';

/// Loại minigame (`game_type` của `GamePredictionResponse`).
///
/// App hiện cho chơi Game 1, 2, 4 (Swagger mục 21); các loại khác vẫn parse
/// được để lịch sử dự đoán không hiện sai.
enum GameType {
  participants('GAME_1_PARTICIPANTS', 'Đoán số người đề xuất', 1),
  approvedQuestions('GAME_2_APPROVED_QUESTIONS', 'Đoán số câu được duyệt', 2),
  authorConfidence('GAME_3_AUTHOR_CONFIDENCE', 'Đoán mức độ yêu thích', 3),
  bankSize('GAME_4_SUBJECT_BANK_SIZE', 'Đoán quy mô ngân hàng đề', 4),
  reportError('GAME_5_REPORT_ERROR', 'Báo câu lỗi', 5),
  llmIdentification('GAME_6_LLM_IDENTIFICATION', 'Đoán câu do AI tạo', 6),
  unknown('', 'Minigame', 0);

  final String apiValue;
  final String label;
  final int number;
  const GameType(this.apiValue, this.label, this.number);

  /// "Minigame 1 · Đoán số người đề xuất"
  String get title => number == 0 ? label : 'Minigame $number · $label';

  static GameType parse(dynamic v) {
    final s = J.stringOr(v).toUpperCase();
    for (final x in values) {
      if (x != unknown && x.apiValue == s) return x;
    }
    return unknown;
  }
}

/// Một lượt dự đoán (`GamePredictionResponse`) - kết quả của các API đặt
/// cược và từng phần tử của `GET /games/my-predictions`.
class GamePrediction extends Equatable {
  final int predictionId;
  final GameType gameType;

  /// `COURSE_CLASS` | `SESSION` | `SUBJECT` | `GAME6_SESSION`
  final String? targetType;
  final int? targetId;
  final Map<String, dynamic> predictionData;
  final Map<String, dynamic> actualData;

  /// false khi server còn `PENDING` (chưa tổng kết).
  final bool resolved;

  /// Chỉ có nghĩa khi [resolved].
  final bool isCorrect;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  const GamePrediction({
    required this.predictionId,
    this.gameType = GameType.unknown,
    this.targetType,
    this.targetId,
    this.predictionData = const {},
    this.actualData = const {},
    this.resolved = false,
    this.isCorrect = false,
    this.createdAt,
    this.resolvedAt,
  });

  factory GamePrediction.fromJson(Map<String, dynamic> json) => GamePrediction(
    predictionId: J.intOr(json['prediction_id']),
    gameType: GameType.parse(json['game_type']),
    targetType: J.asString(json['target_type']),
    targetId: J.asInt(json['target_id']),
    predictionData: J.asMap(json['prediction_data']) ?? const {},
    actualData: J.asMap(json['actual_data']) ?? const {},
    resolved: J.stringOr(json['status']).toUpperCase() == 'RESOLVED',
    isCorrect: J.asBool(json['is_correct']),
    createdAt: J.asDate(json['created_at']),
    resolvedAt: J.asDate(json['resolved_at']),
  );

  static CursorPage<GamePrediction> pageFromJson(dynamic data) {
    final map = J.asMap(data);
    final key = map != null && map['contents'] is List ? 'contents' : 'items';
    return CursorPage.fromJson(data, GamePrediction.fromJson, itemsKey: key);
  }

  /// Mô tả ngắn điều đã đoán, vd "Đoán 12 người".
  String get predictionText => _describe(predictionData) ?? 'Đã đặt dự đoán';

  /// Mô tả kết quả thực tế (null khi chưa tổng kết / server không gửi).
  String? get actualText => resolved ? _describe(actualData) : null;

  /// Đọc số liệu theo từng loại game. Server không chốt tên khoá trong
  /// Swagger (`object`) nên thử cả tên trong request lẫn tên rút gọn.
  String? _describe(Map<String, dynamic> d) {
    if (d.isEmpty) return null;
    int? pick(List<String> keys) {
      for (final k in keys) {
        if (J.asInt(d[k]) case final v?) return v;
      }
      return null;
    }

    switch (gameType) {
      case GameType.participants:
        final n = pick(['predicted_count', 'actual_count', 'count']);
        return n == null ? null : '$n người đề xuất';
      case GameType.approvedQuestions:
        final llm = pick([
          'predicted_llm_count',
          'actual_llm_count',
          'llm_count',
          'llm',
        ]);
        final human = pick([
          'predicted_human_count',
          'actual_human_count',
          'human_count',
          'human',
        ]);
        if (llm == null && human == null) return null;
        return '${llm ?? 0} câu AI · ${human ?? 0} câu tự soạn';
      case GameType.bankSize:
        final n = pick([
          'predicted_bank_size',
          'actual_bank_size',
          'bank_size',
          'count',
        ]);
        return n == null ? null : '$n câu hỏi';
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [
    predictionId,
    gameType,
    targetType,
    targetId,
    predictionData,
    actualData,
    resolved,
    isCorrect,
    createdAt,
    resolvedAt,
  ];
}

/// Lớp học phần để đặt cược Game 1 (`MyCourseClassPredictionDto`).
class Game1Class extends Equatable {
  final int courseClassId;
  final String classCode;
  final String? semester;
  final int? subjectId;
  final String? subjectName;
  final String? lecturerName;

  /// Đã đặt cược cho NGÀY MAI ở lớp này chưa (mỗi ngày một lần).
  final bool alreadyPredicted;
  final int? predictedCount;

  const Game1Class({
    required this.courseClassId,
    this.classCode = '',
    this.semester,
    this.subjectId,
    this.subjectName,
    this.lecturerName,
    this.alreadyPredicted = false,
    this.predictedCount,
  });

  factory Game1Class.fromJson(Map<String, dynamic> json) => Game1Class(
    courseClassId: J.intOr(json['course_class_id']),
    classCode: J.stringOr(json['class_code']),
    semester: J.asString(json['semester'] ?? json['semester_name']),
    subjectId: J.asInt(json['subject_id']),
    subjectName: J.asString(json['subject_name']),
    lecturerName: J.asString(json['lecturer_name']),
    alreadyPredicted: J.asBool(json['already_predicted']),
    predictedCount: J.asInt(json['predicted_count']),
  );

  Game1Class copyWith({bool? alreadyPredicted, int? predictedCount}) =>
      Game1Class(
        courseClassId: courseClassId,
        classCode: classCode,
        semester: semester,
        subjectId: subjectId,
        subjectName: subjectName,
        lecturerName: lecturerName,
        alreadyPredicted: alreadyPredicted ?? this.alreadyPredicted,
        predictedCount: predictedCount ?? this.predictedCount,
      );

  @override
  List<Object?> get props => [
    courseClassId,
    classCode,
    semester,
    subjectId,
    subjectName,
    lecturerName,
    alreadyPredicted,
    predictedCount,
  ];
}

/// Phạm vi bảng xếp hạng.
enum LeaderboardPeriod {
  semester('SEMESTER', 'Học kỳ'),
  subject('SUBJECT', 'Theo môn');

  final String apiValue;
  final String label;
  const LeaderboardPeriod(this.apiValue, this.label);
}

/// Một dòng của bảng xếp hạng (`LeaderboardEntryDto`).
class LeaderboardEntry extends Equatable {
  final int rank;
  final int userId;
  final String? userCode;
  final String fullName;
  final String? avatarUrl;
  final String? frameUrl;
  final double totalPoints;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    this.userCode,
    this.fullName = '',
    this.avatarUrl,
    this.frameUrl,
    this.totalPoints = 0,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: J.intOr(json['rank']),
        userId: J.intOr(json['user_id']),
        userCode: J.asString(json['user_code']),
        fullName: J.stringOr(json['full_name'], 'Người dùng'),
        avatarUrl: J.asString(json['avatar_url']),
        frameUrl: J.asString(json['frame_url']),
        totalPoints: J.asDouble(json['total_points']) ?? 0,
        isCurrentUser: J.asBool(json['is_current_user']),
      );

  @override
  List<Object?> get props => [
    rank,
    userId,
    userCode,
    fullName,
    avatarUrl,
    frameUrl,
    totalPoints,
    isCurrentUser,
  ];
}

/// Thứ hạng của chính mình (`MyRankDto`). [rank] = 0 nghĩa là chưa có điểm.
class MyRank extends Equatable {
  final int rank;
  final double totalPoints;
  final double? topPercent;
  final int totalParticipants;
  final String fullName;
  final String? avatarUrl;
  final String? frameUrl;

  const MyRank({
    this.rank = 0,
    this.totalPoints = 0,
    this.topPercent,
    this.totalParticipants = 0,
    this.fullName = '',
    this.avatarUrl,
    this.frameUrl,
  });

  bool get ranked => rank > 0;

  factory MyRank.fromJson(Map<String, dynamic> json) => MyRank(
    rank: J.intOr(json['rank']),
    totalPoints: J.asDouble(json['total_points']) ?? 0,
    topPercent: J.asDouble(json['top_percent']),
    totalParticipants: J.intOr(json['total_participants']),
    fullName: J.stringOr(json['full_name']),
    avatarUrl: J.asString(json['avatar_url']),
    frameUrl: J.asString(json['frame_url']),
  );

  @override
  List<Object?> get props => [
    rank,
    totalPoints,
    topPercent,
    totalParticipants,
    fullName,
    avatarUrl,
    frameUrl,
  ];
}

/// `GET /games/leaderboard`
class Leaderboard extends Equatable {
  final List<LeaderboardEntry> entries;
  final MyRank? myRank;

  const Leaderboard({this.entries = const [], this.myRank});

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
    entries: J.list(json['entries'], LeaderboardEntry.fromJson),
    myRank: switch (J.asMap(json['my_rank'])) {
      final m? => MyRank.fromJson(m),
      null => null,
    },
  );

  @override
  List<Object?> get props => [entries, myRank];
}

/// Điểm hiển thị gọn: 12.0 -> "12", 12.25 -> "12.25".
String formatPoints(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
