import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/models/game_models.dart';
import 'package:quizhub/data/models/question_models.dart';
import 'package:quizhub/data/models/session_models.dart';
import 'package:quizhub/data/repositories/game_repository.dart';
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
    _json(200, {'code': '1000', 'message': 'SUCCESS', 'data': data});

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

Map<String, dynamic> _prediction({
  String game = 'GAME_1_PARTICIPANTS',
  Map<String, dynamic>? data,
}) => {
  'prediction_id': 1001,
  'game_type': game,
  'target_type': 'COURSE_CLASS',
  'target_id': 101,
  'prediction_data': data ?? {'predicted_count': 5},
  'actual_data': null,
  'status': 'PENDING',
  'is_correct': false,
  'created_at': '2026-10-06T15:00:00Z',
  'resolved_at': null,
};

void main() {
  late _Backend backend;
  late GameRepository repo;

  setUp(() {
    backend = _Backend();
    repo = GameRepository(_client(backend));
  });

  Map<String, dynamic> lastBody() =>
      Map<String, dynamic>.from(backend.requests.last.data as Map);

  group('GameRepository', () {
    test('Game 1 gửi course_class_id + predicted_count', () async {
      backend.routes['POST /games/prediction/participants'] = (_) =>
          _ok(_prediction());
      final p = await repo.predictParticipants(
        courseClassId: 101,
        predictedCount: 5,
      );
      expect(lastBody(), {'course_class_id': 101, 'predicted_count': 5});
      expect(p.gameType, GameType.participants);
      expect(p.resolved, isFalse);
      expect(p.predictionText, '5 người đề xuất');
    });

    test('Game 2 chỉ gửi loại câu có dự đoán', () async {
      backend.routes['POST /games/prediction/approved-questions'] = (_) => _ok(
        _prediction(
          game: 'GAME_2_APPROVED_QUESTIONS',
          data: {'predicted_human_count': 3},
        ),
      );
      final p = await repo.predictApprovedQuestions(
        sessionId: 12,
        humanCount: 3,
      );
      expect(lastBody(), {'session_id': 12, 'predicted_human_count': 3});
      expect(p.predictionText, '0 câu AI · 3 câu tự soạn');
    });

    test('Game 4 gửi subject_id + predicted_bank_size', () async {
      backend.routes['POST /games/prediction/bank-size'] = (_) => _ok(
        _prediction(
          game: 'GAME_4_SUBJECT_BANK_SIZE',
          data: {'predicted_bank_size': 250},
        ),
      );
      final p = await repo.predictBankSize(
        subjectId: 10,
        predictedBankSize: 250,
      );
      expect(lastBody(), {'subject_id': 10, 'predicted_bank_size': 250});
      expect(p.gameType, GameType.bankSize);
      expect(p.predictionText, '250 câu hỏi');
    });

    test('cược trùng: lỗi 409 giữ nguyên message của server', () async {
      backend.routes['POST /games/prediction/bank-size'] = (_) => _json(409, {
        'code': '409',
        'message': 'Bạn đã đặt cược cho môn học này rồi',
      });
      await expectLater(
        repo.predictBankSize(subjectId: 10, predictedBankSize: 1),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message', contains('đã đặt cược')),
        ),
      );
    });

    test('lịch sử đọc khoá `contents` và kết quả đã tổng kết', () async {
      backend.routes['GET /games/my-predictions'] = (_) => _ok({
        'contents': [
          {
            ..._prediction(),
            'status': 'RESOLVED',
            'is_correct': true,
            'actual_data': {'actual_count': 5},
          },
          {..._prediction(game: 'GAME_9_NEW'), 'prediction_id': 7},
        ],
        'pagination': {'after': 7, 'has_next': true},
      });
      final page = await repo.myPredictions(limit: 2);
      expect(backend.requests.last.queryParameters['limit'], 2);
      expect(page.items, hasLength(2));
      expect(page.after, '7');
      expect(page.hasNext, isTrue);
      final first = page.items.first;
      expect(first.resolved && first.isCorrect, isTrue);
      expect(first.actualText, '5 người đề xuất');
      // Loại game app chưa biết vẫn hiển thị được
      expect(page.items.last.gameType, GameType.unknown);
    });

    test('bảng xếp hạng theo môn gửi subject_id', () async {
      backend.routes['GET /games/leaderboard'] = (_) => _ok({
        'entries': [
          {
            'rank': 1,
            'user_id': 42,
            'full_name': 'Nguyễn Văn B',
            'total_points': 1520.5,
            'is_current_user': false,
          },
        ],
        'my_rank': {'rank': 0, 'total_points': 0.0, 'top_percent': 100.0},
      });
      final board = await repo.leaderboard(
        period: LeaderboardPeriod.subject,
        subjectId: 10,
      );
      final q = backend.requests.last.queryParameters;
      expect(q['period'], 'SUBJECT');
      expect(q['subject_id'], 10);
      expect(board.entries.single.totalPoints, 1520.5);
      expect(board.myRank!.ranked, isFalse);

      await repo.leaderboard();
      expect(
        backend.requests.last.queryParameters.containsKey('subject_id'),
        isFalse,
      );
    });

    test('lớp Game 1 đọc trạng thái đã cược', () async {
      backend.routes['GET /games/prediction/game-1/classes'] = (_) => _ok([
        {
          'course_class_id': 101,
          'class_code': 'IT3080_01',
          'subject_name': 'Hệ điều hành',
          'already_predicted': true,
          'predicted_count': 4,
        },
      ]);
      final c = (await repo.game1Classes()).single;
      expect(c.classCode, 'IT3080_01');
      expect(c.alreadyPredicted, isTrue);
      expect(c.predictedCount, 4);
    });
  });

  test('formatPoints bỏ phần thập phân thừa', () {
    expect(formatPoints(12), '12');
    expect(formatPoints(12.25), '12.25');
    expect(formatPoints(2.5), '2.5');
  });

  test('bản xem trước: chơi Game 1, 2, 4 và chặn cược trùng', () async {
    final api = _client(PreviewBackend());
    final games = GameRepository(api);
    final submissions = SubmissionRepository(api);

    // Game 1
    final cls = (await games.game1Classes()).firstWhere(
      (c) => !c.alreadyPredicted,
    );
    await games.predictParticipants(
      courseClassId: cls.courseClassId,
      predictedCount: 8,
    );
    final after = await games.game1Classes();
    expect(
      after.firstWhere((c) => c.courseClassId == cls.courseClassId),
      isA<Game1Class>()
          .having((c) => c.alreadyPredicted, 'alreadyPredicted', isTrue)
          .having((c) => c.predictedCount, 'predictedCount', 8),
    );

    // Game 2: phiên chỉ có câu tự soạn -> cược câu AI bị 400
    final created = await submissions.propose(
      const SessionDraft(
        subjectId: 10,
        title: 'Đồ thị',
        questions: [
          QuestionDraft(
            content: 'BFS dùng cấu trúc nào?',
            options: [
              QuestionOption(key: 'A', text: 'Hàng đợi', isCorrect: true),
              QuestionOption(key: 'B', text: 'Ngăn xếp', isCorrect: false),
            ],
          ),
        ],
      ),
    );
    expect(created.status, SessionStatus.pending);
    await expectLater(
      games.predictApprovedQuestions(sessionId: created.sessionId, llmCount: 1),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
    await games.predictApprovedQuestions(
      sessionId: created.sessionId,
      humanCount: 1,
    );
    await expectLater(
      games.predictApprovedQuestions(
        sessionId: created.sessionId,
        humanCount: 0,
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );

    // Game 4: mỗi môn một lần
    await games.predictBankSize(subjectId: 10, predictedBankSize: 300);
    await expectLater(
      games.predictBankSize(subjectId: 10, predictedBankSize: 200),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );

    final history = await games.myPredictions();
    expect(history.items.take(3).map((p) => p.gameType), [
      GameType.bankSize,
      GameType.approvedQuestions,
      GameType.participants,
    ]);

    final board = await games.leaderboard();
    expect(board.entries.where((e) => e.isCurrentUser), hasLength(1));
    expect(board.myRank!.ranked, isTrue);
  });
}
