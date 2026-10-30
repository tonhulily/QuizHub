import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/widgets/app_button.dart';
import 'package:quizhub/data/models/cursor_page.dart';
import 'package:quizhub/data/models/exam_models.dart';
import 'package:quizhub/data/models/question_models.dart';
import 'package:quizhub/data/models/session_models.dart';
import 'package:quizhub/data/models/subject_model.dart';
import 'package:quizhub/data/repositories/exam_repository.dart';
import 'package:quizhub/data/repositories/subject_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/features/exam/cubit/exam_generator_cubit.dart';
import 'package:quizhub/features/exam/view/exam_detail_view.dart';
import 'package:quizhub/features/exam/view/exam_generator_view.dart';
import 'package:quizhub/features/exam/view/my_exams_view.dart';
import 'package:quizhub/features/question_bank/cubit/load_cubit.dart';
import 'package:quizhub/features/question_bank/cubit/submission_form_cubit.dart';

import '../helpers/fake_profile.dart';

const _subjects = [
  SubjectModel(subjectId: 10, code: 'IT3011', name: 'CTDL & TT'),
  SubjectModel(subjectId: 11, code: 'IT3070', name: 'Hệ điều hành'),
];

const _classes = [
  CourseClassModel(courseClassId: 100, classCode: '171146', subjectId: 10),
  CourseClassModel(courseClassId: 101, classCode: '171150', subjectId: 10),
];

const _exam = ExamDetail(
  examId: 9,
  title: 'Đề giữa kỳ',
  subjectName: 'CTDL & TT',
  questionCount: 1,
  statistic: ExamStatistic(easy: 1),
  questions: [
    ExamQuestion(
      order: 1,
      questionId: 101,
      content: 'Độ phức tạp tìm kiếm trên cây AVL?',
      difficulty: Difficulty.easy,
      options: [
        QuestionOption(key: 'A', text: 'O(log n)', isCorrect: true),
        QuestionOption(key: 'B', text: 'O(n)', isCorrect: false),
      ],
    ),
  ],
);

class _FakeExams implements ExamRepository {
  List<CourseClassModel> classes = _classes;
  final List<GenerateExamInput> generated = [];
  ApiException? classesError;

  @override
  Future<List<CourseClassModel>> myClasses() async {
    final e = classesError;
    if (e != null) throw e;
    return classes;
  }

  @override
  Future<ExamDetail> generate(GenerateExamInput input) async {
    generated.add(input);
    return _exam;
  }

  /// subject_id của từng lần gọi danh sách đề
  final List<int?> listedSubjects = [];

  @override
  Future<CursorPage<ExamSummary>> myExams({
    String? after,
    int limit = ExamRepository.maxPageSize,
    int? subjectId,
  }) async {
    listedSubjects.add(subjectId);
    return CursorPage(
      items: [
        if (subjectId == null || subjectId == 10)
          const ExamSummary(examId: 1, title: 'Đề CTDL', subjectName: 'CTDL'),
        if (subjectId == null || subjectId == 11)
          const ExamSummary(examId: 2, title: 'Đề HĐH', subjectName: 'HĐH'),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubjects implements SubjectRepository {
  @override
  Future<List<SubjectModel>> all({bool refresh = false}) async => _subjects;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GenerateExamInput _input({
  int subjectId = 10,
  int count = 20,
  List<int> classIds = const [100],
  DifficultyRatio? difficulty,
}) => GenerateExamInput(
  subjectId: subjectId,
  questionCount: count,
  classIds: classIds,
  difficulty: difficulty,
);

void main() {
  group('validateExamInput', () {
    test('hợp lệ', () {
      expect(validateExamInput(_input()), isNull);
      expect(
        validateExamInput(
          _input(
            difficulty: const DifficultyRatio(
              easy: 0.3,
              medium: 0.5,
              hard: 0.2,
            ),
          ),
        ),
        isNull,
      );
    });

    test('bắt buộc môn, lớp, số câu trong giới hạn, tổng độ khó 100%', () {
      expect(validateExamInput(_input(subjectId: 0)), 'Hãy chọn môn học.');
      expect(validateExamInput(_input(classIds: [])), contains('lớp học phần'));
      expect(validateExamInput(_input(count: 0)), contains('Số câu'));
      expect(validateExamInput(_input(count: 101)), contains('Số câu'));
      expect(
        validateExamInput(
          _input(difficulty: const DifficultyRatio(easy: 0.6, medium: 0.6)),
        ),
        'Tổng tỉ lệ độ khó phải bằng 100%.',
      );
    });
  });

  test('form đề xuất: tối đa 4 ảnh mỗi câu', () {
    final draft = SessionDraft(
      subjectId: 10,
      title: 'Ảnh',
      questions: [
        QuestionDraft(
          content: 'Hình nào là cây AVL?',
          mediaUrls: [for (var i = 0; i < 5; i++) 'https://x/$i.png'],
          options: const [
            QuestionOption(key: 'A', text: 'Hình 1', isCorrect: true),
            QuestionOption(key: 'B', text: 'Hình 2'),
          ],
        ),
      ],
    );
    expect(validateSessionDraft(draft), 'Câu 1: tối đa 4 ảnh.');
  });

  group('ExamGeneratorCubit', () {
    test('chỉ liệt kê môn có lớp mình dạy', () async {
      final cubit = ExamGeneratorCubit(_FakeExams(), _FakeSubjects());
      await cubit.load();
      expect(cubit.state.status, LoadStatus.loaded);
      expect(cubit.state.teachingSubjects.map((s) => s.code), ['IT3011']);
      expect(cubit.state.classesOf(10), hasLength(2));
    });

    test('lỗi tải lớp thì báo lỗi', () async {
      final exams = _FakeExams()
        ..classesError = const ApiException(
          type: ApiErrorType.forbidden,
          message: 'Không có quyền',
          statusCode: 403,
        );
      final cubit = ExamGeneratorCubit(exams, _FakeSubjects());
      await cubit.load();
      expect(cubit.state.status, LoadStatus.failure);
      expect(cubit.state.error?.statusCode, 403);
    });

    test('tham số sai thì không gọi API; đúng thì trả đề', () async {
      final exams = _FakeExams();
      final cubit = ExamGeneratorCubit(exams, _FakeSubjects());
      await cubit.load();

      final (bad, err) = await cubit.generate(_input(classIds: []));
      expect(bad, isNull);
      expect(err?.type, ApiErrorType.validation);
      expect(exams.generated, isEmpty);

      final (exam, ok) = await cubit.generate(_input());
      expect(ok, isNull);
      expect(exam?.examId, 9);
      expect(exams.generated.single.classIds, [100]);
    });
  });

  group('màn hình', () {
    late _FakeExams exams;

    setUp(() {
      getIt.reset();
      exams = _FakeExams();
      getIt.registerSingleton<ExamRepository>(exams);
      getIt.registerSingleton<SubjectRepository>(_FakeSubjects());
    });

    tearDown(getIt.reset);

    Widget app(Widget home, {UserRole role = UserRole.student}) =>
        withRole(role, MaterialApp(theme: AppTheme.lightTheme, home: home));

    testWidgets('sinh đề: chưa dạy lớp nào thì báo trống', (tester) async {
      exams.classes = const [];
      await tester.pumpWidget(app(const ExamGeneratorView()));
      await tester.pumpAndSettle();
      expect(find.text('Bạn chưa phụ trách lớp nào'), findsOneWidget);
    });

    testWidgets('sinh đề: chưa chọn môn thì báo lỗi, không gọi API', (
      tester,
    ) async {
      await tester.pumpWidget(app(const ExamGeneratorView()));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(AppButton, 'Sinh đề');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pump();
      expect(find.text('Hãy chọn môn học.'), findsOneWidget);
      expect(exams.generated, isEmpty);
    });

    testWidgets('đề của tôi: lọc theo môn mình dạy', (tester) async {
      await tester.pumpWidget(
        app(const MyExamsView(), role: UserRole.lecturer),
      );
      await tester.pumpAndSettle();

      // Chỉ dạy lớp của IT3011 nên không có chip IT3070
      expect(find.widgetWithText(ChoiceChip, 'Tất cả'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'IT3011'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'IT3070'), findsNothing);
      expect(find.text('Đề HĐH'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'IT3011'));
      await tester.pumpAndSettle();
      expect(exams.listedSubjects.last, 10);
      expect(find.text('Đề CTDL'), findsOneWidget);
      expect(find.text('Đề HĐH'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Tất cả'));
      await tester.pumpAndSettle();
      expect(exams.listedSubjects.last, isNull);
    });

    testWidgets('chi tiết đề: sinh viên không có nút AI gợi ý', (tester) async {
      await tester.pumpWidget(
        app(const ExamDetailView(examId: 9, initial: _exam)),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI gợi ý'), findsNothing);
    });

    testWidgets('chi tiết đề: giảng viên có nút AI gợi ý', (tester) async {
      await tester.pumpWidget(
        app(
          const ExamDetailView(examId: 9, initial: _exam),
          role: UserRole.lecturer,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI gợi ý'), findsOneWidget);
    });

    testWidgets('xem trước đề: bật / tắt đáp án', (tester) async {
      await tester.pumpWidget(
        app(const ExamDetailView(examId: 9, initial: _exam)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xem trước đề'), findsOneWidget);
      expect(find.text('Độ phức tạp tìm kiếm trên cây AVL?'), findsOneWidget);
      expect(find.byTooltip('Hiện đáp án'), findsOneWidget);
      await tester.tap(find.byTooltip('Hiện đáp án'));
      await tester.pump();
      expect(find.byTooltip('Ẩn đáp án'), findsOneWidget);
    });
  });
}
