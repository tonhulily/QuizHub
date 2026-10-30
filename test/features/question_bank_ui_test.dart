import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/features/question_bank/cubit/load_cubit.dart';
import 'package:quizhub/features/question_bank/cubit/practice_cubit.dart';
import 'package:quizhub/features/question_bank/cubit/submission_form_cubit.dart';
import 'package:quizhub/features/question_bank/view/practice_view.dart';
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

PracticeQuestion _practice(int id, {bool answered = false}) => PracticeQuestion(
  questionId: id,
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
