import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/router/app_router.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/data/models/cursor_page.dart';
import 'package:quizhub/data/models/game_models.dart';
import 'package:quizhub/data/models/subject_model.dart';
import 'package:quizhub/data/repositories/game_repository.dart';
import 'package:quizhub/data/repositories/subject_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/features/minigame/view/game1_view.dart';
import 'package:quizhub/features/minigame/view/game4_view.dart';
import 'package:quizhub/features/minigame/view/minigame_hub_view.dart';

import '../helpers/fake_profile.dart';

/// GameRepository trong RAM: chặn cược trùng như server (409).
class _FakeGames implements GameRepository {
  final List<GamePrediction> placed = [];
  final Set<int> game1Done = {};

  GamePrediction _add(GameType type, int targetId, Map<String, dynamic> d) {
    final p = GamePrediction(
      predictionId: placed.length + 1,
      gameType: type,
      targetId: targetId,
      predictionData: d,
      createdAt: DateTime.now(),
    );
    placed.insert(0, p);
    return p;
  }

  static const _conflict = ApiException(
    type: ApiErrorType.business,
    statusCode: 409,
    message: 'Bạn đã đặt cược rồi',
  );

  @override
  Future<List<Game1Class>> game1Classes() async => [
    for (final id in [100, 101])
      Game1Class(
        courseClassId: id,
        classCode: 'L$id',
        subjectName: 'Môn $id',
        alreadyPredicted: game1Done.contains(id),
        predictedCount: placed
            .where(
              (p) => p.gameType == GameType.participants && p.targetId == id,
            )
            .map((p) => p.predictionData['predicted_count'] as int)
            .firstOrNull,
      ),
  ];

  @override
  Future<GamePrediction> predictParticipants({
    required int courseClassId,
    required int predictedCount,
  }) async {
    if (!game1Done.add(courseClassId)) throw _conflict;
    return _add(GameType.participants, courseClassId, {
      'predicted_count': predictedCount,
    });
  }

  @override
  Future<GamePrediction> predictBankSize({
    required int subjectId,
    required int predictedBankSize,
  }) async {
    if (placed.any(
      (p) => p.gameType == GameType.bankSize && p.targetId == subjectId,
    )) {
      throw _conflict;
    }
    return _add(GameType.bankSize, subjectId, {
      'predicted_bank_size': predictedBankSize,
    });
  }

  @override
  Future<CursorPage<GamePrediction>> myPredictions({
    String? after,
    int limit = 20,
  }) async => CursorPage(items: List.of(placed));

  @override
  Future<Leaderboard> leaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.semester,
    int? subjectId,
    int limit = 50,
  }) async => const Leaderboard(
    entries: [
      LeaderboardEntry(
        rank: 1,
        userId: 2,
        fullName: 'Lê Thu Hà',
        totalPoints: 90,
      ),
    ],
    myRank: MyRank(
      rank: 3,
      totalPoints: 40,
      topPercent: 5,
      totalParticipants: 60,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubjects implements SubjectRepository {
  @override
  Future<List<SubjectModel>> enrolled() async => const [
    SubjectModel(subjectId: 10, code: 'IT3011', name: 'CTDL & TT'),
    SubjectModel(subjectId: 11, code: 'IT3070', name: 'Hệ điều hành'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget home) => withRole(
  UserRole.student,
  MaterialApp(
    theme: AppTheme.lightTheme,
    builder: EasyLoading.init(),
    onGenerateRoute: AppRouter.onGenerateRoute,
    home: home,
  ),
);

/// Gõ [value] vào ô nhập của hộp thoại dự đoán rồi bấm chốt.
Future<void> _answer(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextFormField).first, value);
  await tester.tap(find.text('Chốt dự đoán'));
  await tester.pumpAndSettle();
}

void main() {
  late _FakeGames games;

  setUp(() async {
    await getIt.reset();
    games = _FakeGames();
    getIt
      ..registerSingleton<GameRepository>(games)
      ..registerSingleton<SubjectRepository>(_FakeSubjects());
  });

  tearDown(getIt.reset);

  testWidgets('màn Minigame: thứ hạng + 3 game, mở được Game 1', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const MinigameHubView()));
    await tester.pumpAndSettle();

    expect(find.text('Thứ hạng của bạn'), findsOneWidget);
    expect(find.text("#3"), findsOneWidget);
    expect(find.text('MINIGAME 1'), findsOneWidget);
    expect(find.text('MINIGAME 2'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('MINIGAME 4'), 200);
    expect(find.text('MINIGAME 4'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('MINIGAME 1'), -200);
    await tester.tap(find.text('Đoán số người đề xuất'));
    await tester.pumpAndSettle();
    expect(find.byType(Game1View), findsOneWidget);
  });

  testWidgets('Game 1: nhập sai thì báo lỗi, chốt xong lớp hiện đã đoán', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const Game1View()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dự đoán cho ngày mai').first);
    await tester.pumpAndSettle();

    await _answer(tester, '0');
    expect(find.text('Tối thiểu 1'), findsOneWidget);

    await _answer(tester, '8');
    expect(find.text('Đã đoán 8 người cho ngày mai'), findsOneWidget);
  });

  testWidgets('Game 4: chốt xong môn hiện số đã đoán, không đoán lại được', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const Game4View()));
    await tester.pumpAndSettle();

    final buttons = find.text('Dự đoán');
    final before = buttons.evaluate().length;
    expect(before, greaterThan(0));

    await tester.tap(buttons.first);
    await tester.pumpAndSettle();
    await _answer(tester, '300');

    expect(find.text('Bạn đoán: 300 câu hỏi'), findsOneWidget);
    expect(find.text('Chờ kết quả'), findsOneWidget);
    expect(find.text('Dự đoán').evaluate().length, before - 1);
  });
}
