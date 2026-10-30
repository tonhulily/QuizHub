import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

/// Danh sách chuỗi (URL ảnh...), bỏ phần tử rỗng.
List<String> jsonStrings(dynamic v) => [
  for (final x in J.asList(v)) ?J.asString(x),
];

/// Nguồn gốc câu hỏi. Backend gọi câu người tự soạn là `HOMO_SAPIENS`.
enum QuestionSource {
  human('HOMO_SAPIENS', 'Tự soạn'),
  llm('LLM', 'AI sinh');

  final String apiValue;
  final String label;
  const QuestionSource(this.apiValue, this.label);

  static QuestionSource parse(dynamic v) =>
      J.stringOr(v).toUpperCase() == 'LLM' ? llm : human;
}

/// Trạng thái duyệt của TỪNG câu hỏi (phiên đã xử lý vẫn có thể có câu bị
/// từ chối).
enum QuestionStatus {
  pending('Chờ duyệt'),
  approved('Đã duyệt'),
  rejected('Bị từ chối'),
  unknown('');

  final String label;
  const QuestionStatus(this.label);

  static QuestionStatus parse(dynamic v) {
    switch (J.stringOr(v).toUpperCase()) {
      case 'PENDING':
        return pending;
      case 'APPROVED':
        return approved;
      case 'REJECTED':
        return rejected;
      default:
        return unknown;
    }
  }
}

/// Độ khó: chỉ có trong đề thi và kết quả tìm kiếm (người đề xuất không chọn).
enum Difficulty {
  unclassified('UNCLASSIFIED', 'Chưa phân loại'),
  easy('EASY', 'Dễ'),
  medium('MEDIUM', 'Trung bình'),
  hard('HARD', 'Khó');

  final String apiValue;
  final String label;
  const Difficulty(this.apiValue, this.label);

  static Difficulty parse(dynamic v) {
    final s = J.stringOr(v).toUpperCase();
    for (final d in values) {
      if (d.apiValue == s) return d;
    }
    return unclassified;
  }
}

/// Thang 0-4 của backend, dùng chung cho "độ tự tin" khi đề xuất và "đánh
/// giá" câu hỏi của người khác.
///
/// Nhãn theo đúng Swagger (`POST /questions/{id}/rate`): 0 là "Hoàn toàn sai".
enum RatingLevel {
  wrong(0, 'Hoàn toàn sai'),
  hallucinated(1, 'LLM bịa'),
  shaky(2, 'Tác giả chưa vững'),
  basic(3, 'Cơ bản'),
  great(4, 'Câu hỏi hay');

  final int value;
  final String label;
  const RatingLevel(this.value, this.label);

  static RatingLevel? fromValue(num? v) {
    if (v == null) return null;
    final i = v.round();
    return values[i < 0 ? 0 : (i > 4 ? 4 : i)];
  }
}

/// Một phương án trả lời (`QuestionOption` / `OptionDto`).
class QuestionOption extends Equatable {
  /// A, B, C, D...
  final String key;
  final String text;

  /// null khi backend ẩn đáp án (câu luyện tập chưa trả lời).
  final bool? isCorrect;
  final String? mediaUrl;
  final int? mediaId;

  const QuestionOption({
    required this.key,
    required this.text,
    this.isCorrect,
    this.mediaUrl,
    this.mediaId,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
    key: J.stringOr(json['key']),
    text: J.stringOr(json['text'] ?? json['content']),
    isCorrect: json['is_correct'] == null ? null : J.asBool(json['is_correct']),
    mediaUrl: J.asString(json['media_url']),
    mediaId: J.asInt(json['media_id']),
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'text': text.trim(),
    'is_correct': isCorrect ?? false,
    if (mediaUrl != null) 'media_url': mediaUrl,
    if (mediaId != null) 'media_id': mediaId,
  };

  @override
  List<Object?> get props => [key, text, isCorrect, mediaUrl, mediaId];
}

/// Một câu hỏi trong kết quả `GET /search?type=QUESTION`
/// (`QuestionSearchResultDto`).
class QuestionHit extends Equatable {
  final int questionId;
  final String? questionCode;
  final String content;
  final int? subjectId;
  final String? subjectName;
  final Difficulty difficulty;
  final List<QuestionOption> options;

  /// Phiên chứa câu hỏi. Swagger CHƯA có trường này (API_CONTRACT mục 6);
  /// backend trả thì bấm vào câu mở được phiên, không thì chỉ xem trước.
  final int? sessionId;
  final int ratingCount;
  final int commentCount;

  const QuestionHit({
    required this.questionId,
    this.questionCode,
    required this.content,
    this.subjectId,
    this.subjectName,
    this.difficulty = Difficulty.unclassified,
    this.options = const [],
    this.sessionId,
    this.ratingCount = 0,
    this.commentCount = 0,
  });

  factory QuestionHit.fromJson(Map<String, dynamic> json) => QuestionHit(
    questionId: J.intOr(json['question_id'] ?? json['id']),
    questionCode: J.asString(json['question_code']),
    content: J.stringOr(json['content']),
    subjectId: J.asInt(json['subject_id']),
    subjectName: J.asString(json['subject_name']),
    difficulty: Difficulty.parse(json['difficulty']),
    options: J.list(json['options'], QuestionOption.fromJson),
    sessionId: J.asInt(
      json['session_id'] ?? J.asMap(json['session'])?['session_id'],
    ),
    ratingCount: J.intOr(json['rating_count']),
    commentCount: J.intOr(json['comment_count']),
  );

  @override
  List<Object?> get props => [
    questionId,
    questionCode,
    content,
    subjectId,
    subjectName,
    difficulty,
    options,
    sessionId,
    ratingCount,
    commentCount,
  ];
}

/// Câu hỏi để luyện tập (`PracticeQuestionDto` trong
/// `GET /sessions/{id}/questions`).
///
/// Câu chưa trả lời: [QuestionOption.isCorrect] là null, [correctAnswer] và
/// [explanation] cũng null. Trả lời xong dùng [withAnswer] để hiện kết quả.
class PracticeQuestion extends Equatable {
  final int questionId;
  final String? questionCode;
  final String content;
  final List<String> imageUrls;
  final List<QuestionOption> options;
  final QuestionSource source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// `updated_at` đúng nguyên văn server gửi. Gửi lại khi trả lời để server
  /// phát hiện câu đã bị sửa (412) mà không lệch do đổi múi giờ / định dạng.
  final String? updatedAtRaw;
  final bool answered;
  final bool rated;
  final String? correctAnswer;
  final String? explanation;
  final int reactCount;
  final int commentCount;
  final int ratingCount;

  const PracticeQuestion({
    required this.questionId,
    this.questionCode,
    required this.content,
    this.imageUrls = const [],
    this.options = const [],
    this.source = QuestionSource.human,
    this.createdAt,
    this.updatedAt,
    this.updatedAtRaw,
    this.answered = false,
    this.rated = false,
    this.correctAnswer,
    this.explanation,
    this.reactCount = 0,
    this.commentCount = 0,
    this.ratingCount = 0,
  });

  factory PracticeQuestion.fromJson(Map<String, dynamic> json) {
    final mine = J.asMap(json['my_interaction']) ?? const <String, dynamic>{};
    final hidden = J.asMap(json['hidden_fields']) ?? const <String, dynamic>{};
    return PracticeQuestion(
      questionId: J.intOr(json['question_id'] ?? json['id']),
      questionCode: J.asString(json['question_code']),
      content: J.stringOr(json['content']),
      imageUrls: jsonStrings(json['image_urls'] ?? json['media_urls']),
      options: J.list(json['options'], QuestionOption.fromJson),
      source: QuestionSource.parse(json['source']),
      createdAt: J.asDate(json['created_at']),
      updatedAt: J.asDate(json['updated_at']),
      updatedAtRaw: J.asString(json['updated_at']),
      answered: J.asBool(mine['answered']),
      rated: J.asBool(mine['rated']),
      correctAnswer: J.asString(hidden['correct_answer']),
      explanation: J.asString(hidden['explanation']),
      reactCount: J.intOr(json['react_count']),
      commentCount: J.intOr(json['comment_count']),
      ratingCount: J.intOr(json['rating_count']),
    );
  }

  PracticeQuestion _copy({
    bool? answered,
    bool? rated,
    String? correctAnswer,
    String? explanation,
    int? ratingCount,
  }) => PracticeQuestion(
    questionId: questionId,
    questionCode: questionCode,
    content: content,
    imageUrls: imageUrls,
    options: options,
    source: source,
    createdAt: createdAt,
    updatedAt: updatedAt,
    updatedAtRaw: updatedAtRaw,
    answered: answered ?? this.answered,
    rated: rated ?? this.rated,
    correctAnswer: correctAnswer ?? this.correctAnswer,
    explanation: explanation ?? this.explanation,
    reactCount: reactCount,
    commentCount: commentCount,
    ratingCount: ratingCount ?? this.ratingCount,
  );

  /// Sau khi nộp đáp án: server đã trả đáp án đúng + lời giải.
  PracticeQuestion withAnswer(AnswerResult r) => _copy(
    answered: true,
    correctAnswer: r.correctAnswer,
    explanation: r.explanation,
  );

  /// Sau khi đánh giá.
  PracticeQuestion withRating(RateResult r) =>
      _copy(rated: true, ratingCount: r.ratingCount);

  @override
  List<Object?> get props => [
    questionId,
    content,
    imageUrls,
    options,
    source,
    updatedAtRaw,
    answered,
    rated,
    correctAnswer,
    explanation,
    reactCount,
    commentCount,
    ratingCount,
  ];
}

/// Kết quả chấm (`POST /questions/{id}/answer`).
class AnswerResult extends Equatable {
  final bool isCorrect;

  /// Khoá đáp án đúng, vd "A" (hoặc "A,C" nếu nhiều đáp án).
  final String correctAnswer;
  final String? explanation;

  const AnswerResult({
    required this.isCorrect,
    required this.correctAnswer,
    this.explanation,
  });

  List<String> get correctKeys => [
    for (final k in correctAnswer.split(','))
      if (k.trim().isNotEmpty) k.trim(),
  ];

  factory AnswerResult.fromJson(Map<String, dynamic> json) {
    final raw = json['correct_answer'];
    return AnswerResult(
      isCorrect: J.asBool(json['is_correct']),
      correctAnswer: raw is List ? raw.join(',') : J.stringOr(raw),
      explanation: J.asString(json['explanation']),
    );
  }

  @override
  List<Object?> get props => [isCorrect, correctAnswer, explanation];
}

/// Kết quả sau khi đánh giá (`POST /questions/{id}/rate`).
class RateResult extends Equatable {
  final double avgRating;
  final int ratingCount;

  const RateResult({required this.avgRating, required this.ratingCount});

  factory RateResult.fromJson(Map<String, dynamic> json) => RateResult(
    avgRating: J.asDouble(json['new_avg_rating']) ?? 0,
    ratingCount: J.intOr(json['new_rating_count']),
  );

  @override
  List<Object?> get props => [avgRating, ratingCount];
}

/// Một lượt đánh giá (`GET /questions/{id}/ratings`).
///
/// Backend chỉ trả `user_id`, chưa có tên / ảnh người đánh giá.
class RatingItem extends Equatable {
  final int userId;
  final double rating;
  final bool isError;
  final String? comment;
  final DateTime? createdAt;

  const RatingItem({
    required this.userId,
    required this.rating,
    this.isError = false,
    this.comment,
    this.createdAt,
  });

  RatingLevel? get level => RatingLevel.fromValue(rating);

  factory RatingItem.fromJson(Map<String, dynamic> json) => RatingItem(
    userId: J.intOr(json['user_id']),
    rating: J.asDouble(json['rating']) ?? 0,
    isError: J.asBool(json['is_error']),
    comment: J.asString(json['comment']),
    createdAt: J.asDate(json['created_at']),
  );

  @override
  List<Object?> get props => [userId, rating, isError, comment, createdAt];
}

/// Thống kê một câu hỏi (`GET /questions/{id}/statistics`).
class QuestionStatistics extends Equatable {
  final int totalAnswers;

  /// Tỉ lệ trả lời đúng, 0.0 - 1.0
  final double correctRate;

  /// Số lượt chọn từng phương án: {"A": 117, "B": 15...}
  final Map<String, int> optionDistribution;
  final double avgRating;
  final int totalRatings;

  /// Số lượt đánh giá theo từng mức 0-4
  final Map<int, int> ratingDistribution;

  const QuestionStatistics({
    this.totalAnswers = 0,
    this.correctRate = 0,
    this.optionDistribution = const {},
    this.avgRating = 0,
    this.totalRatings = 0,
    this.ratingDistribution = const {},
  });

  factory QuestionStatistics.fromJson(Map<String, dynamic> json) {
    final options =
        J.asMap(json['option_distribution']) ?? const <String, dynamic>{};
    final summary =
        J.asMap(json['rating_summary']) ?? const <String, dynamic>{};
    final ratings =
        J.asMap(summary['distribution']) ?? const <String, dynamic>{};
    return QuestionStatistics(
      totalAnswers: J.intOr(json['total_answer'] ?? json['total_answers']),
      correctRate: J.asDouble(json['correct_rate']) ?? 0,
      optionDistribution: {
        for (final e in options.entries) e.key: J.intOr(e.value),
      },
      avgRating: J.asDouble(summary['avg_rating']) ?? 0,
      totalRatings: J.intOr(summary['total_ratings']),
      ratingDistribution: {
        for (final e in ratings.entries) ?int.tryParse(e.key): J.intOr(e.value),
      },
    );
  }

  @override
  List<Object?> get props => [
    totalAnswers,
    correctRate,
    optionDistribution,
    avgRating,
    totalRatings,
    ratingDistribution,
  ];
}
