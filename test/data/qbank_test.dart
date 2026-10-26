import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/models/ai_models.dart';
import 'package:quizhub/data/models/exam_models.dart';
import 'package:quizhub/data/models/question_models.dart';
import 'package:quizhub/data/models/session_models.dart';
import 'package:quizhub/data/repositories/ai_repository.dart';
import 'package:quizhub/data/repositories/exam_repository.dart';
import 'package:quizhub/data/repositories/question_bank_repository.dart';
import 'package:quizhub/data/repositories/submission_repository.dart';
import 'package:quizhub/dev/preview_backend.dart';

/// Backend giả định tuyến theo "METHOD path", ghi lại mọi request.
class _Backend implements HttpClientAdapter {
  final Map<String, ResponseBody Function(RequestOptions o)> routes = {};
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(o);
    final handler = routes['${o.method} ${o.path}'];
    return handler == null ? _ok(null) : handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _ok(dynamic data) =>
    _json(200, {'code': '0000', 'message': 'ok', 'data': data});

class _Tokens extends TokenStorage {
  @override
  String? get accessToken => 'a';
  @override
  String? get refreshToken => 'r';
  @override
  bool get hasTokens => true;
  @override
  Future<void> load() async {}
}

ApiClient _client(HttpClientAdapter adapter) => ApiClient(
  tokens: _Tokens(),
  events: SessionEvents(),
  baseUrl: 'https://example.com/api/v1',
  adapter: adapter,
);

const _draft = SessionDraft(
  subjectId: 10,
  title: '  Bảng băm ',
  content: '   ',
  questions: [
    QuestionDraft(
      content: 'Kỹ thuật nào dùng danh sách liên kết?',
      options: [
        QuestionOption(key: 'A', text: 'Separate chaining', isCorrect: true),
        QuestionOption(key: 'B', text: 'Linear probing', isCorrect: false),
      ],
      source: QuestionSource.llm,
      confidence: 3,
    ),
  ],
);

void main() {
  group('models', () {
    test('danh sách phiên đọc khoá contents và con trỏ dạng số', () {
      final page = SubmissionSummary.pageFromJson({
        'contents': [
          {
            'session_id': 101,
            'title': 'Ôn tập Design Patterns',
            'subject_code': 'IT3180',
            'question_counts': 5,
            'status': 'PENDING',
          },
        ],
        'pagination': {'after': 101, 'has_next': true},
      });
      final s = page.items.single;
      expect(s.questionCount, 5);
      expect(s.status, SessionStatus.pending);
      expect(s.status.editable, isTrue);
      expect(page.after, '101');
      expect(page.hasNext, isTrue);
    });

    test('trạng thái thiếu hoặc lạ thì là unknown và khoá sửa', () {
      expect(SessionStatus.parse(null), SessionStatus.unknown);
      expect(SessionStatus.parse('ARCHIVED'), SessionStatus.unknown);
      expect(SessionStatus.parse('resolved'), SessionStatus.resolved);
      expect(SessionStatus.unknown.editable, isFalse);
    });

    test('câu luyện tập ẩn đáp án cho tới khi trả lời', () {
      final q = PracticeQuestion.fromJson({
        'question_id': 105,
        'content': 'Thuật toán nào gây đói?',
        'updated_at': '2026-10-06T09:00:00Z',
        'options': [
          {'key': 'A', 'text': 'RR'},
          {'key': 'B', 'text': 'SJF'},
        ],
        'my_interaction': {'answered': false, 'rated': false},
        'hidden_fields': {'correct_answer': null, 'explanation': null},
      });
      expect(q.options.first.isCorrect, isNull);
      expect(q.answered, isFalse);
      expect(q.correctAnswer, isNull);
      expect(q.updatedAtRaw, '2026-10-06T09:00:00Z');

      final done = q.withAnswer(
        AnswerResult.fromJson({
          'is_correct': false,
          'correct_answer': 'B',
          'explanation': 'SJF ưu tiên tiến trình ngắn',
        }),
      );
      expect(done.answered, isTrue);
      expect(done.correctAnswer, 'B');
      expect(done.explanation, 'SJF ưu tiên tiến trình ngắn');
    });

    test('đáp án đúng đọc được cả chuỗi lẫn danh sách', () {
      expect(AnswerResult.fromJson({'correct_answer': 'A, C'}).correctKeys, [
        'A',
        'C',
      ]);
      expect(
        AnswerResult.fromJson({
          'correct_answer': ['B'],
        }).correctKeys,
        ['B'],
      );
    });

    test('body tạo phiên và sửa phiên khác nhau', () {
      final propose = _draft.toProposeJson();
      expect(propose['title'], 'Bảng băm');
      expect(propose.containsKey('content'), isFalse);
      final pq = (propose['questions'] as List).single as Map;
      expect(pq['llm_generated'], isTrue);
      expect(pq.containsKey('source'), isFalse);
      expect(pq['options'], hasLength(2));

      final update = _draft.toUpdateJson();
      final uq = (update['questions'] as List).single as Map;
      expect(uq['source'], 'LLM');
      expect(uq.containsKey('question_id'), isTrue);
      expect(uq['question_id'], isNull);
      expect(uq.containsKey('llm_generated'), isFalse);
    });

    test('thống kê đọc phân bố phương án và phân bố sao', () {
      final st = QuestionStatistics.fromJson({
        'total_answer': 150,
        'correct_rate': 0.78,
        'option_distribution': {'A': 117, 'B': 15, 'C': 10, 'D': 8},
        'rating_summary': {
          'avg_rating': 3.85,
          'total_ratings': 42,
          'distribution': {'0': 1, '3': 15, '4': 20},
        },
      });
      expect(st.optionDistribution['A'], 117);
      expect(st.ratingDistribution[4], 20);
      expect(st.totalRatings, 42);
    });

    test('AI: refusal_reason là chuỗi "null" thì không phải từ chối', () {
      final r = AiRefineResult.fromJson({
        'edit_log_id': 105,
        'suggested_question': {
          'content': 'Từ khoá nào ngăn kế thừa?',
          'options': [
            {'key': 'A', 'text': 'final', 'is_correct': true},
          ],
          'refusal_reason': 'null',
        },
        'hallucination_audit': {
          'is_hallucinated': false,
          'confidence_score': 0.95,
          'violations': [
            {'type': 'CONTRADICTION', 'severity': 'HIGH'},
          ],
        },
      });
      expect(r.refused, isFalse);
      expect(r.options.single.isCorrect, isTrue);
      expect(r.violations.single.severity, 'HIGH');
    });

    test('đề thi sắp câu theo thứ tự và đếm độ khó', () {
      final e = ExamDetail.fromJson({
        'exam_id': 5,
        'title': 'Giữa kỳ',
        'questions': [
          {'order': 2, 'question_id': 2, 'difficulty': 'HARD'},
          {'order': 1, 'question_id': 1, 'difficulty': 'EASY'},
        ],
        'statistic': {'easy_count': 1, 'hard_count': 1},
      });
      expect(e.questions.first.questionId, 1);
      expect(e.questions.last.difficulty, Difficulty.hard);
      expect(e.statistic.total, 2);
      expect(e.questionCount, 2);
    });

    test('tỉ lệ độ khó phải có tổng 1.0', () {
      expect(
        const DifficultyRatio(easy: 0.3, medium: 0.5, hard: 0.2).isValid,
        isTrue,
      );
      expect(const DifficultyRatio(easy: 0.5, medium: 0.6).isValid, isFalse);
    });
  });

  group('repositories', () {
    late _Backend backend;
    late SubmissionRepository submissions;
    late QuestionBankRepository bank;
    late ExamRepository exams;
    late AiRepository ai;

    setUp(() {
      backend = _Backend();
      final api = _client(backend);
      submissions = SubmissionRepository(api);
      bank = QuestionBankRepository(api);
      exams = ExamRepository(api);
      ai = AiRepository(api);
    });

    test('mySubmissions gửi bộ lọc và bỏ tham số rỗng', () async {
      backend.routes['GET /sessions/my-submissions'] = (o) => _ok({
        'contents': [
          {'session_id': 1, 'title': 'A'},
        ],
        'pagination': {'after': null, 'has_next': false},
      });
      final page = await submissions.mySubmissions(
        status: SessionStatus.pending,
        subjectId: 10,
      );
      final query = backend.requests.single.queryParameters;
      expect(query['status'], 'PENDING');
      expect(query['subject_id'], 10);
      expect(query.containsKey('after'), isFalse);
      expect(page.items.single.sessionId, 1);
    });

    test('answer gửi updated_at nguyên văn', () async {
      backend.routes['POST /questions/105/answer'] = (o) => _ok({
        'is_correct': true,
        'correct_answer': 'A',
        'explanation': 'vì...',
      });
      final r = await bank.answer(105, [
        'A',
      ], questionUpdatedAt: '2026-10-06T09:00:00Z');
      expect(r.isCorrect, isTrue);
      final body = backend.requests.single.data as Map;
      expect(body['selected_options'], ['A']);
      expect(body['question_updated_at'], '2026-10-06T09:00:00Z');
    });

    test('trả lời lại: lỗi 409 giữ nguyên statusCode cho UI', () async {
      backend.routes['POST /questions/105/answer'] = (o) =>
          _json(409, {'code': '1010', 'message': 'Bạn đã trả lời câu này'});
      await expectLater(
        bank.answer(105, ['A']),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message', 'Bạn đã trả lời câu này'),
        ),
      );
    });

    test('rate gửi 0 điểm khi báo lỗi', () async {
      backend.routes['POST /questions/7/rate'] = (o) =>
          _ok({'new_avg_rating': 2.5, 'new_rating_count': 4});
      final r = await bank.rate(7, rating: 4, isError: true, comment: '  ');
      final body = backend.requests.single.data as Map;
      expect(body['rating'], 0);
      expect(body['is_error'], isTrue);
      expect(body.containsKey('comment'), isFalse);
      expect(r.ratingCount, 4);
    });

    test('searchSessions chỉ lấy kết quả loại SESSION', () async {
      backend.routes['GET /search'] = (o) => _ok({
        'items': [
          {
            'type': 'SESSION',
            'session': {
              'session_id': 7,
              'title': 'Hệ điều hành',
              'status': 'RESOLVED',
              'question_count': 3,
            },
          },
          {
            'type': 'USER',
            'user': {'user_id': 2},
          },
        ],
        'pagination': {'after': 10, 'has_next': true},
        'total_hits': 30,
      });
      final page = await bank.searchSessions('os');
      expect(backend.requests.single.queryParameters['type'], 'SESSION');
      expect(page.items.single.questionCount, 3);
      expect(page.items.single.status, SessionStatus.resolved);
      expect(page.after, '10');
    });

    test('xuất đề gửi đúng tham số', () async {
      backend.routes['GET /exams/5/export'] = (o) => _ok({
        'download_url': 'https://x.test/de.pdf',
        'file_size_mb': 1.25,
        'questions_count': 40,
      });
      final r = await exams.exportFile(5, includeAnswerKey: true);
      final query = backend.requests.single.queryParameters;
      expect(query['format'], 'pdf');
      expect(query['include_answer_key'], true);
      expect(query['paper_size'], 'A4');
      expect(r.downloadUrl, 'https://x.test/de.pdf');
    });

    test('AI apply gửi edit_log_id và quyết định', () async {
      backend.routes['POST /questions/42/ai-apply'] = (o) =>
          _ok({'question_id': 42, 'status': 'APPLIED'});
      final r = await ai.apply(42, editLogId: 105, approve: true);
      final body = backend.requests.single.data as Map;
      expect(body, {'edit_log_id': 105, 'approve': true});
      expect(r.applied, isTrue);
    });
  });

  test('bản xem trước chạy trọn luồng của sinh viên', () async {
    final api = _client(PreviewBackend());
    final submissions = SubmissionRepository(api);
    final bank = QuestionBankRepository(api);
    final exams = ExamRepository(api);

    final created = await submissions.propose(_draft);
    expect(created.status, SessionStatus.pending);
    final mine = await submissions.mySubmissions(status: SessionStatus.pending);
    expect(mine.items.map((s) => s.sessionId), contains(created.sessionId));
    final detail = await submissions.detail(created.sessionId);
    expect(detail.questions.single.options.first.isCorrect, isTrue);

    final found = await bank.searchSessions('');
    expect(found.items, isNotEmpty);
    expect(
      found.items.every((s) => s.status == SessionStatus.resolved),
      isTrue,
    );

    final session = await bank.sessionQuestions(found.items.first.sessionId);
    final q = session.questions.first;
    expect(q.answered, isFalse);
    expect(q.options.every((o) => o.isCorrect == null), isTrue);

    final result = await bank.answer(q.questionId, [q.options.first.key]);
    expect(result.correctKeys, isNotEmpty);
    final again = await bank.sessionQuestions(session.sessionId);
    expect(again.questions.first.answered, isTrue);

    final exam = await exams.generate(
      const GenerateExamInput(subjectId: 10, questionCount: 5, classIds: [100]),
    );
    expect(exam.questions, isNotEmpty);

    await submissions.delete(created.sessionId);
    final after = await submissions.mySubmissions(
      status: SessionStatus.pending,
    );
    expect(
      after.items.map((s) => s.sessionId),
      isNot(contains(created.sessionId)),
    );
  });
}
