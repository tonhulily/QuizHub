import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/config/app_config.dart';
import 'package:quizhub/core/design_system/app_icons.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/data/models/cursor_page.dart';
import 'package:quizhub/data/models/question_models.dart';
import 'package:quizhub/data/models/session_models.dart';
import 'package:quizhub/data/models/subject_model.dart';
import 'package:quizhub/data/repositories/question_bank_repository.dart';
import 'package:quizhub/data/repositories/subject_repository.dart';
import 'package:quizhub/data/repositories/submission_repository.dart';
import 'package:quizhub/data/repositories/user_directory.dart';
import 'package:quizhub/data/repositories/user_repository.dart';
import 'package:quizhub/data/models/profile_model.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/data/models/comment_model.dart';
import 'package:quizhub/data/models/react_result.dart';
import 'package:quizhub/data/repositories/comment_repository.dart';
import 'package:quizhub/data/repositories/reaction_repository.dart';
import 'package:quizhub/features/question_bank/view/submission_detail_view.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/features/question_bank/cubit/load_cubit.dart';
import 'package:quizhub/features/question_bank/cubit/practice_cubit.dart';
import 'package:quizhub/features/question_bank/cubit/submission_form_cubit.dart';
import 'package:quizhub/features/question_bank/view/practice_view.dart';
import 'package:quizhub/features/question_bank/view/question_stats_view.dart';
import 'package:quizhub/features/question_bank/view/submission_form_view.dart';

import '../helpers/fake_profile.dart';

// ---------------------------------------------------------------- dữ liệu

QuestionDraft _q({
  String content = 'Độ phức tạp tìm kiếm trên bảng băm?',
  List<QuestionOption>? options,
}) => QuestionDraft(
  content: content,
  options:
      options ??
      const [
        QuestionOption(key: 'A', text: 'O(1)', isCorrect: true),
        QuestionOption(key: 'B', text: 'O(n)', isCorrect: false),
      ],
);

SessionDraft _draft({
  int subjectId = 10,
  String title = 'Bảng băm',
  String? sourceUrl,
  List<QuestionDraft>? questions,
}) => SessionDraft(
  subjectId: subjectId,
  title: title,
  sourceUrl: sourceUrl,
  questions: questions ?? [_q()],
);

PracticeQuestion _practice(
  int id, {
  bool answered = false,
  QuestionSource source = QuestionSource.human,
}) => PracticeQuestion(
  questionId: id,
  source: source,
  content: 'Câu $id',
  updatedAtRaw: '2026-10-20T08:00:00Z',
  answered: answered,
  correctAnswer: answered ? 'A' : null,
  options: const [
    QuestionOption(key: 'A', text: 'Đúng'),
    QuestionOption(key: 'B', text: 'Sai'),
  ],
);

// ---------------------------------------------------------------- repo giả

class _FakeBank implements QuestionBankRepository {
  List<PracticeQuestion> questions;
  final List<(int, List<String>, String?)> answers = [];
  ApiException? answerError;

  _FakeBank(this.questions);

  @override
  Future<SessionQuestions> sessionQuestions(int sessionId) async =>
      SessionQuestions(
        sessionId: sessionId,
        title: 'Phiên mẫu',
        subjectCode: 'IT3011',
        questions: questions,
      );

  @override
  Future<AnswerResult> answer(
    int questionId,
    List<String> selectedKeys, {
    String? questionUpdatedAt,
  }) async {
    answers.add((questionId, selectedKeys, questionUpdatedAt));
    final e = answerError;
    if (e != null) throw e;
    return AnswerResult(
      isCorrect: selectedKeys.first == 'A',
      correctAnswer: 'A',
      explanation: 'Vì A đúng.',
    );
  }

  @override
  Future<RateResult> rate(
    int questionId, {
    required int rating,
    bool isError = false,
    String? comment,
  }) async => const RateResult(avgRating: 3, ratingCount: 1);

  List<RatingItem> ratingItems = const [];

  @override
  Future<QuestionStatistics> statistics(int questionId) async =>
      const QuestionStatistics(
        totalAnswers: 4,
        correctRate: 0.5,
        optionDistribution: {'A': 2, 'B': 2},
        avgRating: 2,
        totalRatings: 2,
        ratingDistribution: {0: 1, 2: 1},
      );

  @override
  Future<CursorPage<RatingItem>> ratings(
    int questionId, {
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) async => CursorPage(items: ratingItems);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `GET /users/{id}`: người #5 có hồ sơ, người khác lỗi; đếm số lần gọi.
class _FakeUsers implements UserRepository {
  final Map<int, int> calls = {};

  @override
  Future<ProfileModel> getUser(int userId) async {
    calls[userId] = (calls[userId] ?? 0) + 1;
    if (userId == 5) {
      return const ProfileModel(userId: 5, fullName: 'Trần Thị B');
    }
    throw const ApiException(type: ApiErrorType.notFound, message: '404');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `POST /react`: ghi lại đối tượng đã thích, trả số của server.
class _FakeReactions implements ReactionRepository {
  final List<(TargetType, int)> toggled = [];

  @override
  Future<ReactResult> toggleLike({
    required TargetType targetType,
    required int targetId,
  }) async {
    toggled.add((targetType, targetId));
    return const ReactResult(myReaction: 'LIKE', totalCount: 3);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `GET /comments`: chưa có bình luận nào; ghi lại đối tượng được hỏi.
class _FakeComments implements CommentRepository {
  final List<(TargetType, int)> listed = [];

  @override
  Future<CursorPage<CommentModel>> list({
    required TargetType targetType,
    required int targetId,
    int? parentCommentId,
    bool newestFirst = true,
    String? after,
    int limit = 20,
  }) async {
    listed.add((targetType, targetId));
    return const CursorPage();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubjects implements SubjectRepository {
  @override
  Future<List<SubjectModel>> enrolled() async => const [
    SubjectModel(subjectId: 10, code: 'IT3011', name: 'CTDL & TT'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubmissions implements SubmissionRepository {
  final List<SessionDraft> proposed = [];

  @override
  Future<SubmissionDetail> detail(int sessionId) async => SubmissionDetail(
    sessionId: sessionId,
    title: 'Bảng băm',
    status: SessionStatus.resolved,
    questions: const [
      SubmissionQuestion(
        questionId: 301,
        content: 'Đụng độ là gì?',
        reactCount: 2,
        commentCount: 1,
        options: [
          QuestionOption(key: 'A', text: 'Hai khoá cùng ô', isCorrect: true),
          QuestionOption(key: 'B', text: 'Bảng đầy', isCorrect: false),
        ],
      ),
    ],
  );

  @override
  Future<ProposeResult> propose(SessionDraft draft) async {
    proposed.add(draft);
    return const ProposeResult(sessionId: 1);
  }

  @override
  Future<CursorPage<SubmissionSummary>> mySubmissions({
    String? after,
    int limit = AppConfig.defaultPageSize,
    int? subjectId,
    SessionStatus? status,
  }) async => const CursorPage();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('validateSessionDraft', () {
    test('phiên hợp lệ thì không báo lỗi', () {
      expect(validateSessionDraft(_draft()), isNull);
    });

    test('bắt buộc môn, tiêu đề và ít nhất một câu', () {
      expect(validateSessionDraft(_draft(subjectId: 0)), 'Hãy chọn môn học.');
      expect(
        validateSessionDraft(_draft(title: '   ')),
        'Hãy nhập tiêu đề phiên.',
      );
      expect(
        validateSessionDraft(_draft(questions: [])),
        'Phiên phải có ít nhất một câu hỏi.',
      );
    });

    test('link nguồn phải là http(s)', () {
      expect(validateSessionDraft(_draft(sourceUrl: 'abc')), contains('http'));
      expect(
        validateSessionDraft(_draft(sourceUrl: 'https://hust.edu.vn')),
        isNull,
      );
    });

    test('câu hỏi: nội dung, phương án trống / trùng, đúng một đáp án', () {
      String? check(QuestionDraft q) =>
          validateSessionDraft(_draft(questions: [q]));

      expect(check(_q(content: ' ')), startsWith('Câu 1: hãy nhập nội dung'));
      expect(
        check(
          _q(
            options: const [
              QuestionOption(key: 'A', text: 'x', isCorrect: true),
            ],
          ),
        ),
        contains('ít nhất 2 phương án'),
      );
      expect(
        check(
          _q(
            options: const [
              QuestionOption(key: 'A', text: 'x', isCorrect: true),
              QuestionOption(key: 'B', text: ' '),
            ],
          ),
        ),
        contains('phương án B đang để trống'),
      );
      expect(
        check(
          _q(
            options: const [
              QuestionOption(key: 'A', text: 'O(1)', isCorrect: true),
              QuestionOption(key: 'B', text: 'o(1) '),
            ],
          ),
        ),
        contains('trùng nhau'),
      );
      expect(
        check(
          _q(
            options: const [
              QuestionOption(key: 'A', text: 'x', isCorrect: true),
              QuestionOption(key: 'B', text: 'y', isCorrect: true),
            ],
          ),
        ),
        contains('đúng một đáp án đúng'),
      );
      expect(
        check(_q(content: List.filled(501, 'từ').join(' '))),
        contains('500 từ'),
      );
    });

    // QH-QA-002: hai phương án chỉ có ảnh (text rỗng) không bị báo trùng
    test('phương án chỉ có ảnh thì hợp lệ', () {
      expect(
        validateSessionDraft(
          _draft(
            questions: [
              _q(
                options: const [
                  QuestionOption(
                    key: 'A',
                    text: '',
                    mediaUrl: 'https://img/a.png',
                    isCorrect: true,
                  ),
                  QuestionOption(
                    key: 'B',
                    text: '',
                    mediaUrl: 'https://img/b.png',
                  ),
                ],
              ),
            ],
          ),
        ),
        isNull,
      );
    });
  });

  group('checkSessionDraft: chỉ ra ô bị lỗi', () {
    test('lỗi thông tin phiên không gắn với câu nào', () {
      final i = checkSessionDraft(_draft(title: ' '))!;
      expect(i.field, DraftField.title);
      expect(i.question, isNull);
    });

    test('phương án trống / trùng chỉ đúng phương án đó', () {
      final empty = checkSessionDraft(
        _draft(
          questions: [
            _q(),
            _q(
              options: const [
                QuestionOption(key: 'A', text: 'x', isCorrect: true),
                QuestionOption(key: 'B', text: ' '),
              ],
            ),
          ],
        ),
      )!;
      expect(empty.field, DraftField.options);
      expect((empty.question, empty.option), (1, 1));

      final dup = checkSessionDraft(
        _draft(
          questions: [
            _q(
              options: const [
                QuestionOption(key: 'A', text: 'O(1)', isCorrect: true),
                QuestionOption(key: 'B', text: 'O(n)'),
                QuestionOption(key: 'C', text: 'o(1)'),
              ],
            ),
          ],
        ),
      )!;
      expect((dup.field, dup.option), (DraftField.options, 2));
    });

    test('chưa chọn đáp án đúng thì báo ở nhóm phương án', () {
      final i = checkSessionDraft(
        _draft(
          questions: [
            _q(
              options: const [
                QuestionOption(key: 'A', text: 'x'),
                QuestionOption(key: 'B', text: 'y'),
              ],
            ),
          ],
        ),
      )!;
      expect((i.field, i.question, i.option), (DraftField.correct, 0, null));
    });
  });

  group('UserDirectory', () {
    test(
      'mỗi người chỉ gọi API một lần; lỗi thì null và lần sau thử lại',
      () async {
        final users = _FakeUsers();
        final dir = UserDirectory(users);

        final both = await Future.wait([dir.lookup(5), dir.lookup(5)]);
        expect(both.map((p) => p?.fullName), ['Trần Thị B', 'Trần Thị B']);
        expect(users.calls[5], 1);

        expect(await dir.lookup(6), isNull);
        expect(await dir.lookup(6), isNull);
        expect(users.calls[6], 2);
      },
    );
  });

  // QH-QA-001: rời màn hình trước khi tải xong thì không emit sau close()
  group('LoadCubit', () {
    test('tải xong sau khi đã đóng thì bỏ qua, không ném lỗi', () async {
      final gate = Completer<int>();
      final cubit = LoadCubit<int>(() => gate.future);
      final loading = cubit.load();
      await cubit.close();
      gate.complete(1);
      await expectLater(loading, completes);
    });

    test('lỗi tải sau khi đã đóng cũng bỏ qua', () async {
      final gate = Completer<int>();
      final cubit = LoadCubit<int>(() => gate.future);
      final loading = cubit.load();
      await cubit.close();
      gate.completeError(
        const ApiException(type: ApiErrorType.server, message: 'lỗi'),
      );
      await expectLater(loading, completes);
    });
  });

  group('PracticeCubit', () {
    test('mở phiên thì nhảy tới câu đầu tiên chưa làm', () async {
      final cubit = PracticeCubit(
        _FakeBank([_practice(1, answered: true), _practice(2)]),
        7,
      );
      await cubit.load();
      expect(cubit.state.status, LoadStatus.loaded);
      expect(cubit.state.index, 1);
      expect(cubit.state.answeredCount, 1);
    });

    test('mở từ kết quả tìm câu hỏi thì nhảy tới câu đó', () async {
      final cubit = PracticeCubit(
        _FakeBank([_practice(1), _practice(2), _practice(3)]),
        7,
        focusQuestionId: 3,
      );
      await cubit.load();
      expect(cubit.state.index, 2);
    });

    test('chưa chọn đáp án thì không gọi API', () async {
      final bank = _FakeBank([_practice(1)]);
      final cubit = PracticeCubit(bank, 7);
      await cubit.load();
      final e = await cubit.submit();
      expect(e?.type, ApiErrorType.validation);
      expect(bank.answers, isEmpty);
    });

    test('nộp gửi updated_at, lưu kết quả và khoá câu', () async {
      final bank = _FakeBank([_practice(1)]);
      final cubit = PracticeCubit(bank, 7);
      await cubit.load();
      cubit.select('B');
      expect(await cubit.submit(), isNull);

      final (id, keys, updatedAt) = bank.answers.single;
      expect(id, 1);
      expect(keys, ['B']);
      expect(updatedAt, '2026-10-20T08:00:00Z');
      final q = cubit.state.current!;
      expect(q.answered, isTrue);
      expect(cubit.state.results[1]!.isCorrect, isFalse);
      expect(cubit.state.correctKeysOf(q), ['A']);

      // Câu đã nộp thì không đổi lựa chọn, không nộp lại được
      cubit.select('A');
      expect(cubit.state.selected[1], 'B');
      expect(await cubit.submit(), isNull);
      expect(bank.answers, hasLength(1));
    });

    test('409 (đã trả lời ở nơi khác) thì tải lại phiên', () async {
      final bank = _FakeBank([_practice(1)])
        ..answerError = const ApiException(
          type: ApiErrorType.server,
          message: 'conflict',
          statusCode: 409,
        );
      final cubit = PracticeCubit(bank, 7);
      await cubit.load();
      cubit.select('A');
      bank.questions = [_practice(1, answered: true)];

      final e = await cubit.submit();
      expect(e?.message, 'Bạn đã trả lời câu này rồi.');
      expect(cubit.state.current!.answered, isTrue);
      expect(cubit.state.submitting, isFalse);
    });

    test('đánh giá xong thì đánh dấu đã đánh giá', () async {
      final cubit = PracticeCubit(_FakeBank([_practice(1, answered: true)]), 7);
      await cubit.load();
      expect(await cubit.rate(rating: 4), isNull);
      expect(cubit.state.current!.rated, isTrue);
    });
  });

  group('màn hình', () {
    late _FakeSubmissions submissions;

    setUp(() {
      getIt.reset();
      submissions = _FakeSubmissions();
      getIt.registerSingleton<SubmissionRepository>(submissions);
      getIt.registerSingleton<SubjectRepository>(_FakeSubjects());
    });

    tearDown(getIt.reset);

    Widget app(Widget home, {UserRole role = UserRole.student}) =>
        withRole(role, MaterialApp(theme: AppTheme.lightTheme, home: home));

    testWidgets('form: gửi khi thiếu dữ liệu thì báo lỗi, không gọi API', (
      tester,
    ) async {
      await tester.pumpWidget(app(const SubmissionFormView()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Gửi'));
      await tester.pump();

      expect(find.text('Hãy chọn môn học.'), findsOneWidget);
      expect(submissions.proposed, isEmpty);
    });

    testWidgets('form: câu mới không chọn sẵn đáp án đúng', (tester) async {
      await tester.pumpWidget(app(const SubmissionFormView()));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Chọn A là đáp án đúng'), findsOneWidget);
      expect(find.byIcon(AppIcons.success), findsNothing);
    });

    testWidgets('thống kê: nhãn mức đánh giá đúng và không bị cắt', (
      tester,
    ) async {
      getIt.registerSingleton<QuestionBankRepository>(_FakeBank(const []));
      getIt.registerSingleton<UserDirectory>(UserDirectory(_FakeUsers()));
      await tester.pumpWidget(
        app(const QuestionStatsView(questionId: 1, correctKeys: ['A'])),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 · Hoàn toàn sai'), findsOneWidget);
      final shaky = find.text('2 · Tác giả chưa vững');
      expect(shaky, findsOneWidget);
      final text = tester.renderObject<RenderParagraph>(shaky);
      expect(text.didExceedMaxLines, isFalse);
    });

    testWidgets('thống kê: hiện tên người đánh giá, lỗi thì hiện id', (
      tester,
    ) async {
      getIt.registerSingleton<QuestionBankRepository>(
        _FakeBank(const [])
          ..ratingItems = const [
            RatingItem(userId: 5, rating: 4, comment: 'Hay'),
            RatingItem(userId: 6, rating: 3),
          ],
      );
      getIt.registerSingleton<UserDirectory>(UserDirectory(_FakeUsers()));
      // Đủ cao để thấy danh sách nhận xét dưới phần thống kê
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const QuestionStatsView(questionId: 1)));
      await tester.pumpAndSettle();

      expect(find.text('Trần Thị B'), findsOneWidget);
      expect(find.text('Người dùng #5'), findsNothing);
      expect(find.text('Người dùng #6'), findsOneWidget);
    });

    for (final (role, visible) in [
      (UserRole.student, true),
      (UserRole.lecturer, false),
    ]) {
      testWidgets('luyện tập: nguồn câu hỏi ${visible ? 'hiện' : 'ẩn'} với '
          '${role.name}', (tester) async {
        getIt.registerSingleton<QuestionBankRepository>(
          _FakeBank([_practice(1, source: QuestionSource.llm)]),
        );
        await tester.pumpWidget(
          app(const PracticeView(sessionId: 7), role: role),
        );
        await tester.pumpAndSettle();
        expect(find.text('AI sinh'), visible ? findsOneWidget : findsNothing);
      });
    }

    testWidgets('form: báo cho sinh viên giảng viên không thấy nguồn', (
      tester,
    ) async {
      await tester.pumpWidget(app(const SubmissionFormView()));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Giảng viên không thấy nguồn này'),
        findsOneWidget,
      );
    });

    testWidgets('chi tiết phiên: thích và bình luận từng câu hỏi', (
      tester,
    ) async {
      final reactions = _FakeReactions();
      final comments = _FakeComments();
      getIt.registerSingleton<ReactionRepository>(reactions);
      getIt.registerSingleton<CommentRepository>(comments);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const SubmissionDetailView(sessionId: 3)));
      await tester.pumpAndSettle();
      expect(find.text('2 lượt thích'), findsOneWidget);
      expect(find.text('1 bình luận'), findsOneWidget);

      await tester.tap(find.text('Thích'));
      await tester.pumpAndSettle();
      expect(reactions.toggled.single, (TargetType.question, 301));
      expect(find.text('3 lượt thích'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Bình luận'));
      await tester.pumpAndSettle();
      expect(comments.listed.single, (TargetType.question, 301));
      expect(find.text('Chưa có bình luận'), findsOneWidget);
    });

    testWidgets('luyện tập: chọn, nộp rồi thấy kết quả và lời giải', (
      tester,
    ) async {
      getIt.registerSingleton<QuestionBankRepository>(
        _FakeBank([_practice(1)]),
      );
      await tester.pumpWidget(app(const PracticeView(sessionId: 7)));
      await tester.pumpAndSettle();

      expect(find.text('Câu 1/1'), findsOneWidget);
      await tester.tap(find.text('Đúng'));
      await tester.pump();
      await tester.tap(find.text('Nộp đáp án'));
      await tester.pumpAndSettle();

      expect(find.text('Chính xác!'), findsOneWidget);
      expect(find.text('Vì A đúng.'), findsOneWidget);
      expect(find.text('Đánh giá'), findsOneWidget);
    });
  });
}
