import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/services/chat_realtime.dart';
import 'package:quizhub/core/services/social_events.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/data/models/author_model.dart';
import 'package:quizhub/data/models/chat_models.dart';
import 'package:quizhub/data/models/comment_model.dart';
import 'package:quizhub/data/models/cursor_page.dart';
import 'package:quizhub/data/models/exam_models.dart';
import 'package:quizhub/data/models/post_model.dart';
import 'package:quizhub/data/models/react_result.dart';
import 'package:quizhub/data/models/subject_model.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/data/repositories/comment_repository.dart';
import 'package:quizhub/data/repositories/exam_repository.dart';
import 'package:quizhub/data/repositories/reaction_repository.dart';
import 'package:quizhub/data/repositories/subject_repository.dart';
import 'package:quizhub/data/repositories/submission_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/features/chat/view/chat_detail_view.dart';
import 'package:quizhub/features/chat/view/conversations_view.dart';
import 'package:quizhub/features/chat/widgets/chat_message_tile.dart';
import 'package:quizhub/features/exam/view/exam_generator_view.dart';
import 'package:quizhub/features/question_bank/view/submission_form_view.dart';
import 'package:quizhub/shared/comment/comments_sheet.dart';
import 'package:quizhub/shared/post/post_card.dart';

import '../helpers/chat_fixture.dart';
import '../helpers/fake_profile.dart';

const _longName =
    'Trần Thị Lan với tên hiển thị rất dài cho màn hình nhỏ và cỡ chữ lớn';
final _longText = List.filled(
  48,
  'Nội dung dài có thể xuống dòng đầy đủ',
).join(' ');

Widget _app(Widget home, {UserRole role = UserRole.student}) => withRole(
  role,
  MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
      child: child!,
    ),
    home: home,
  ),
);

Finder _scrollableIn(Finder listView) => find.descendant(
  of: listView,
  matching: find.byType(Scrollable),
).first;

void _narrow(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _ConversationRows implements ChatRepository {
  @override
  Future<CursorPage<ChatConversation>> conversations({String? after}) async =>
      CursorPage(
        items: [
          ChatConversation(
            conversationId: 1,
            title: _longName,
            lastMessage: ChatMessage(
              messageId: 1,
              conversationId: 1,
              senderId: 2,
              content: _longText,
            ),
          ),
        ],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Comments implements CommentRepository {
  final CommentModel root = CommentModel(
    commentId: 71,
    content: _longText,
    author: AuthorModel(userId: 2, fullName: _longName),
    replyCount: 1,
  );
  final CommentModel reply = CommentModel(
    commentId: 72,
    parentCommentId: 71,
    content: _longText,
    author: const AuthorModel(
      userId: 3,
      fullName: 'Trần Thị Lan · phản hồi với tên rất dài trên điện thoại',
    ),
  );

  @override
  Future<CursorPage<CommentModel>> list({
    required TargetType targetType,
    required int targetId,
    int? parentCommentId,
    bool newestFirst = true,
    String? after,
    int limit = 20,
  }) async => CursorPage(items: parentCommentId == null ? [root] : [reply]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reactions implements ReactionRepository {
  final Completer<ReactResult>? pending;
  int calls = 0;
  _Reactions({this.pending});

  @override
  Future<ReactResult> toggleLike({
    required TargetType targetType,
    required int targetId,
  }) {
    calls++;
    return pending?.future ??
        Future.value(const ReactResult(myReaction: 'LIKE', totalCount: 1));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _commentsHost() => withRole(
  UserRole.student,
  MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showCommentsSheet(
            context,
            targetType: TargetType.post,
            targetId: 71,
          ),
          child: const Text('Mở bình luận'),
        ),
      ),
    ),
  ),
);

class _Subjects implements SubjectRepository {
  @override
  Future<List<SubjectModel>> all({bool refresh = false}) async => const [
    SubjectModel(subjectId: 10, code: 'IT3011', name: 'Cấu trúc dữ liệu'),
  ];

  @override
  Future<List<SubjectModel>> enrolled({bool currentSemester = false}) async =>
      all();

  @override
  Future<List<EnrolledCourseClass>> enrolledClasses() async => const [
    EnrolledCourseClass(
      courseClassId: 1,
      classCode: 'IT3011.2026.1.01',
      subjectId: 10,
      subjectCode: 'IT3011',
      subjectName: 'Cấu trúc dữ liệu',
      activeSemester: true,
      canPropose: true,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Classes implements ExamRepository {
  @override
  Future<List<CourseClassModel>> myClasses() async => const [
    CourseClassModel(
      courseClassId: 101,
      classCode: 'IT3011.2026.1.01',
      subjectId: 10,
      subjectCode: 'IT3011',
      subjectName: 'Cấu trúc dữ liệu',
      semesterName: 'Học kỳ 1 năm học 2026–2027',
      totalStudents: 120,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Submissions implements SubmissionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ChatFixture> _setupChat(
  WidgetTester tester, {
  ChatRepository? repository,
}) async {
  await getIt.reset();
  final fixture = ChatFixture();
  getIt.registerSingleton<ChatRepository>(repository ?? fixture.repo);
  getIt.registerSingleton<ChatRealtime>(fixture.data.realtime);
  getIt.registerSingleton<SocialEvents>(
    SocialEvents(),
    dispose: (events) => events.dispose(),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await getIt.reset();
    await fixture.dispose();
  });
  return fixture;
}

void main() {
  testWidgets('chat: tên và tin dài vẫn cho thấy composer khi bàn phím mở', (
    tester,
  ) async {
    _narrow(tester);
    final fixture = await _setupChat(tester);
    fixture.data.messages[1]!.last['content'] = _longText;
    await tester.pumpWidget(
      _app(
        ChatDetailView(
          target: ChatTarget.conversation(
            const ChatConversation(conversationId: 1, title: _longName),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();

    final send = find.byTooltip('Gửi lượt thích');
    expect(send, findsOneWidget);
    expect(tester.getRect(send).bottom, lessThanOrEqualTo(380));
    expect(send.hitTestable(), findsOneWidget);
    expect(find.byType(ChatMessageTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conversation list: search/filter remain usable with long rows', (
    tester,
  ) async {
    _narrow(tester);
    await _setupChat(tester, repository: _ConversationRows());
    await tester.pumpWidget(_app(const ConversationsView()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation_search')), findsOneWidget);
    expect(find.text('Chưa đọc'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('conversation_search')));
    await tester.enterText(
      find.byKey(const ValueKey('conversation_search')),
      'không có kết quả',
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy cuộc trò chuyện'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feed: long author/post text does not cover available actions', (
    tester,
  ) async {
    _narrow(tester);
    await getIt.reset();
    addTearDown(getIt.reset);
    final post = PostModel(
      postId: 71,
      content: _longText,
      author: const AuthorModel(userId: 2, fullName: _longName),
      reactCount: 3,
      commentCount: 2,
      createdAt: DateTime.now(),
    );
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SingleChildScrollView(child: PostCard(post: post)),
        ),
      ),
    );
    expect(find.text(_longName), findsOneWidget);
    expect(find.text('Xem thêm'), findsOneWidget);
    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bình luận'));
    expect(find.text('Bình luận'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comments: long root/reply text and input fit narrow sheet', (
    tester,
  ) async {
    _narrow(tester);
    await getIt.reset();
    getIt.registerSingleton<CommentRepository>(_Comments());
    getIt.registerSingleton<ReactionRepository>(_Reactions());
    addTearDown(getIt.reset);
    await tester.pumpWidget(_commentsHost());
    await tester.tap(find.text('Mở bình luận'));
    await tester.pumpAndSettle();
    expect(find.text(_longName), findsOneWidget);
    final showReplies = find.text('Xem 1 phản hồi');
    await tester.scrollUntilVisible(
      showReplies,
      160,
      scrollable: _scrollableIn(find.byType(ListView).last),
    );
    expect(showReplies.hitTestable(), findsOneWidget);
    await tester.tap(showReplies);
    await tester.pumpAndSettle();
    final reply = find.byKey(const ValueKey('comment_72'));
    await tester.scrollUntilVisible(
      reply,
      160,
      scrollable: _scrollableIn(find.byType(ListView).last),
    );
    expect(reply, findsOneWidget);
    final input = find.byType(TextField).last;
    await tester.showKeyboard(input);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();
    expect(tester.getRect(input).bottom, lessThanOrEqualTo(390));
    expect(input.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing comments sheet while reaction is pending is safe', (
    tester,
  ) async {
    _narrow(tester);
    await getIt.reset();
    final pending = Completer<ReactResult>();
    final reactions = _Reactions(pending: pending);
    getIt.registerSingleton<CommentRepository>(_Comments());
    getIt.registerSingleton<ReactionRepository>(reactions);
    addTearDown(getIt.reset);
    await tester.pumpWidget(_commentsHost());
    await tester.tap(find.text('Mở bình luận'));
    await tester.pumpAndSettle();
    final like = find.descendant(
      of: find.byKey(const ValueKey('comment_71')),
      matching: find.text('Thích'),
    );
    await tester.scrollUntilVisible(
      like,
      160,
      scrollable: _scrollableIn(find.byType(ListView).last),
    );
    expect(like.hitTestable(), findsOneWidget);
    await tester.tap(like);
    await tester.pump();
    expect(reactions.calls, 1);
    expect(pending.isCompleted, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    pending.complete(const ReactResult(myReaction: 'LIKE', totalCount: 1));
    await tester.pumpAndSettle();
    expect(find.text('Bình luận'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('question form: submit error scrolls to required field', (
    tester,
  ) async {
    _narrow(tester);
    await getIt.reset();
    getIt.registerSingleton<SubmissionRepository>(_Submissions());
    getIt.registerSingleton<SubjectRepository>(_Subjects());
    addTearDown(getIt.reset);
    await tester.pumpWidget(_app(const SubmissionFormView()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi').last);
    await tester.pumpAndSettle();
    expect(find.text('Hãy chọn lớp học phần.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exam generator: required-field feedback remains reachable', (
    tester,
  ) async {
    _narrow(tester);
    await getIt.reset();
    getIt.registerSingleton<ExamRepository>(_Classes());
    getIt.registerSingleton<SubjectRepository>(_Subjects());
    addTearDown(getIt.reset);
    await tester.pumpWidget(
      _app(const ExamGeneratorView(), role: UserRole.lecturer),
    );
    await tester.pumpAndSettle();
    final generate = find.text('Sinh đề');
    await tester.scrollUntilVisible(
      generate,
      160,
      scrollable: _scrollableIn(find.byType(ListView).first),
    );
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(find.text('Hãy chọn môn học.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
