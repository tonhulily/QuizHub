import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'question_models.dart';

/// Số câu theo độ khó trong một đề (`Statistic`).
class ExamStatistic extends Equatable {
  final int easy;
  final int medium;
  final int hard;
  final int unclassified;

  const ExamStatistic({
    this.easy = 0,
    this.medium = 0,
    this.hard = 0,
    this.unclassified = 0,
  });

  int get total => easy + medium + hard + unclassified;

  factory ExamStatistic.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    return ExamStatistic(
      easy: J.intOr(m['easy_count']),
      medium: J.intOr(m['medium_count']),
      hard: J.intOr(m['hard_count']),
      unclassified: J.intOr(m['unclassified_count']),
    );
  }

  @override
  List<Object?> get props => [easy, medium, hard, unclassified];
}

/// Một đề trong danh sách (`ExamItem` của `GET /exams/my-exams`).
class ExamSummary extends Equatable {
  final int examId;
  final String title;
  final String? subjectName;
  final int questionCount;
  final DateTime? createdAt;
  final ExamStatistic statistic;

  /// Link PDF đã xuất trước đó (nếu có)
  final String? downloadUrl;

  const ExamSummary({
    required this.examId,
    required this.title,
    this.subjectName,
    this.questionCount = 0,
    this.createdAt,
    this.statistic = const ExamStatistic(),
    this.downloadUrl,
  });

  factory ExamSummary.fromJson(Map<String, dynamic> json) => ExamSummary(
    examId: J.intOr(json['exam_id'] ?? json['id']),
    title: J.stringOr(json['title'], 'Đề thi'),
    subjectName: J.asString(json['subject_name']),
    questionCount: J.intOr(json['question_count']),
    createdAt: J.asDate(json['created_at']),
    statistic: ExamStatistic.fromJson(J.asMap(json['statistic'])),
    downloadUrl: J.asString(json['download_url']),
  );

  @override
  List<Object?> get props => [examId, title, subjectName, questionCount];
}

/// Một câu trong đề (`ExamQuestionDto`).
class ExamQuestion extends Equatable {
  /// Thứ tự trong đề, bắt đầu từ 1
  final int order;
  final int questionId;
  final String content;
  final List<String> imageUrls;
  final List<QuestionOption> options;
  final Difficulty difficulty;
  final String? topic;

  const ExamQuestion({
    required this.order,
    required this.questionId,
    required this.content,
    this.imageUrls = const [],
    this.options = const [],
    this.difficulty = Difficulty.unclassified,
    this.topic,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) => ExamQuestion(
    order: J.intOr(json['order']),
    questionId: J.intOr(json['question_id']),
    content: J.stringOr(json['content']),
    imageUrls: jsonStrings(json['image_urls']),
    options: J.list(json['options'], QuestionOption.fromJson),
    difficulty: Difficulty.parse(json['difficulty']),
    topic: J.asString(json['topic']),
  );

  @override
  List<Object?> get props => [
    order,
    questionId,
    content,
    options,
    difficulty,
    topic,
  ];
}

/// Chi tiết đề (`ExamDetailResponse`): trả về từ cả `GET /exams/{id}` và
/// `POST /exams/generate`.
class ExamDetail extends Equatable {
  final int examId;
  final String title;
  final String? subjectName;
  final int questionCount;
  final List<ExamQuestion> questions;
  final ExamStatistic statistic;
  final DateTime? createdAt;

  const ExamDetail({
    required this.examId,
    required this.title,
    this.subjectName,
    this.questionCount = 0,
    this.questions = const [],
    this.statistic = const ExamStatistic(),
    this.createdAt,
  });

  factory ExamDetail.fromJson(Map<String, dynamic> json) {
    final questions = J.list(json['questions'], ExamQuestion.fromJson)
      ..sort((a, b) => a.order.compareTo(b.order));
    return ExamDetail(
      examId: J.intOr(json['exam_id'] ?? json['id']),
      title: J.stringOr(json['title'], 'Đề thi'),
      subjectName: J.asString(json['subject_name']),
      questionCount: J.asInt(json['question_count']) ?? questions.length,
      questions: questions,
      statistic: ExamStatistic.fromJson(J.asMap(json['statistic'])),
      createdAt: J.asDate(json['created_at']),
    );
  }

  @override
  List<Object?> get props => [examId, title, questionCount, questions];
}

/// Tỉ lệ độ khó khi sinh đề (`DifficultyDistribution`), mỗi giá trị 0.0 - 1.0.
class DifficultyRatio extends Equatable {
  final double easy;
  final double medium;
  final double hard;
  final double unclassified;

  const DifficultyRatio({
    this.easy = 0,
    this.medium = 0,
    this.hard = 0,
    this.unclassified = 0,
  });

  double get sum => easy + medium + hard + unclassified;

  /// Backend mô tả "tổng các giá trị tương đương 1.0"; cho sai số làm tròn.
  bool get isValid =>
      easy >= 0 &&
      medium >= 0 &&
      hard >= 0 &&
      unclassified >= 0 &&
      (sum - 1).abs() < 0.001;

  Map<String, dynamic> toJson() => {
    'easy': easy,
    'medium': medium,
    'hard': hard,
    'unclassified': unclassified,
  };

  @override
  List<Object?> get props => [easy, medium, hard, unclassified];
}

/// Tham số sinh đề (`GenerateExamRequest`).
class GenerateExamInput extends Equatable {
  final int subjectId;

  /// Bỏ trống thì backend tự đặt tên
  final String? title;
  final int questionCount;
  final DifficultyRatio? difficulty;

  /// Trọng số theo chủ đề / chương, vd {"Chương 1": 0.2}
  final Map<String, double> topicWeights;
  final bool shuffleOptions;
  final bool includeAnswerKey;

  /// Lớp học phần áp dụng đề: bắt buộc, ít nhất 1
  final List<int> classIds;

  const GenerateExamInput({
    required this.subjectId,
    this.title,
    required this.questionCount,
    this.difficulty,
    this.topicWeights = const {},
    this.shuffleOptions = true,
    this.includeAnswerKey = false,
    required this.classIds,
  });

  Map<String, dynamic> toJson() => {
    'subject_id': subjectId,
    if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
    'question_count': questionCount,
    if (difficulty != null) 'difficulty_distribution': difficulty!.toJson(),
    if (topicWeights.isNotEmpty) 'topic_weights': topicWeights,
    'shuffle_options': shuffleOptions,
    'include_answer_key': includeAnswerKey,
    'class_ids': classIds,
  };

  @override
  List<Object?> get props => [
    subjectId,
    title,
    questionCount,
    difficulty,
    topicWeights,
    shuffleOptions,
    includeAnswerKey,
    classIds,
  ];
}

/// Định dạng xuất đề. Swagger ghi "pdf hoặc excel/xlsx": chưa rõ backend nhận
/// chữ nào cho Excel, kiểm tra bằng JSON thật (API_CONTRACT.md mục 6).
enum ExportFormat {
  pdf('pdf', 'PDF'),
  excel('excel', 'Excel');

  final String apiValue;
  final String label;
  const ExportFormat(this.apiValue, this.label);
}

/// Kết quả xuất file (`ExportResponse`): link tải có hạn.
class ExportResult extends Equatable {
  final String downloadUrl;
  final double? fileSizeMb;
  final int questionsCount;
  final DateTime? expiresAt;

  const ExportResult({
    required this.downloadUrl,
    this.fileSizeMb,
    this.questionsCount = 0,
    this.expiresAt,
  });

  factory ExportResult.fromJson(Map<String, dynamic> json) => ExportResult(
    downloadUrl: J.stringOr(json['download_url']),
    fileSizeMb: J.asDouble(json['file_size_mb']),
    questionsCount: J.intOr(json['questions_count']),
    expiresAt: J.asDate(json['expires_at']),
  );

  @override
  List<Object?> get props => [downloadUrl, fileSizeMb, questionsCount];
}

/// Lớp học phần giảng viên phụ trách (`CourseClassResponse`).
class CourseClassModel extends Equatable {
  final int courseClassId;
  final String classCode;
  final int? subjectId;
  final String? subjectCode;
  final String? subjectName;
  final String? semesterName;
  final String? lecturerName;
  final int totalStudents;

  const CourseClassModel({
    required this.courseClassId,
    required this.classCode,
    this.subjectId,
    this.subjectCode,
    this.subjectName,
    this.semesterName,
    this.lecturerName,
    this.totalStudents = 0,
  });

  factory CourseClassModel.fromJson(Map<String, dynamic> json) =>
      CourseClassModel(
        courseClassId: J.intOr(json['course_class_id'] ?? json['id']),
        classCode: J.stringOr(json['class_code']),
        subjectId: J.asInt(json['subject_id']),
        subjectCode: J.asString(json['subject_code']),
        subjectName: J.asString(json['subject_name']),
        semesterName: J.asString(json['semester_name']),
        lecturerName: J.asString(json['lecturer_name']),
        totalStudents: J.intOr(json['total_students']),
      );

  @override
  List<Object?> get props => [courseClassId, classCode, subjectId];
}
