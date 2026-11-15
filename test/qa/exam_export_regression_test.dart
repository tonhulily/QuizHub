import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/data/models/exam_models.dart';
import 'package:quizhub/data/models/question_models.dart';
import 'package:quizhub/data/repositories/exam_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/features/exam/view/exam_detail_view.dart';

import '../helpers/fake_profile.dart';

const _exam = ExamDetail(
  examId: 9,
  title: 'Repro export',
  questionCount: 1,
  questions: [
    ExamQuestion(
      order: 1,
      questionId: 3,
      content: 'Question',
      options: [QuestionOption(key: 'A', text: 'Answer')],
    ),
  ],
);

class _ExportRepo implements ExamRepository {
  bool exported = false;

  @override
  Future<ExportResult> exportFile(
    int examId, {
    ExportFormat format = ExportFormat.pdf,
    bool includeAnswerKey = false,
    String paperSize = 'A4',
  }) async {
    exported = true;
    return const ExportResult(
      downloadUrl: 'https://files.example.test/exam.pdf',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  testWidgets(
    'export launcher PlatformException shows feedback without escaping',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      final repo = _ExportRepo();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await getIt.reset();
      getIt.registerSingleton<ExamRepository>(repo);
      messenger.setMockMethodCallHandler(_launcherChannel, (_) async {
        throw PlatformException(
          code: 'ACTIVITY_NOT_FOUND',
          message: 'No Activity found to handle intent',
        );
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(_launcherChannel, null);
        tester.view.reset();
        await getIt.reset();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: EasyLoading.init(),
          home: withRole(
            UserRole.lecturer,
            const ExamDetailView(examId: 9, initial: _exam),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xuất PDF / Excel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xuất file'));
      await tester.pumpAndSettle();

      expect(repo.exported, isTrue);
      expect(find.text('Không mở được file vừa xuất.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
