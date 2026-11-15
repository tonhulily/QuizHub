import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_colors.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/data/models/author_model.dart';
import 'package:quizhub/data/models/comment_model.dart';
import 'package:quizhub/data/models/cursor_page.dart';
import 'package:quizhub/data/models/profile_model.dart';
import 'package:quizhub/data/models/react_result.dart';
import 'package:quizhub/data/repositories/comment_repository.dart';
import 'package:quizhub/data/repositories/reaction_repository.dart';
import 'package:quizhub/data/repositories/user_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/features/profile/cubit/profile_cubit.dart';
import 'package:quizhub/shared/comment/comment_tile.dart';
import 'package:quizhub/shared/comment/comments_cubit.dart';
import 'package:quizhub/shared/comment/comments_sheet.dart';

const _root = CommentModel(
  commentId: 201,
  content: 'Bình luận gốc',
  author: AuthorModel(userId: 2, fullName: 'Lan'),
  reactCount: 3,
  replyCount: 1,
);
const _reply = CommentModel(
  commentId: 202,
  parentCommentId: 201,
  content: 'Một phản hồi',
  author: AuthorModel(userId: 1, fullName: 'An'),
  reactCount: 2,
);

class _Comments implements CommentRepository {
  @override
  Future<CursorPage<CommentModel>> list({
    required TargetType targetType,
    required int targetId,
    int? parentCommentId,
    bool newestFirst = true,
    String? after,
    int limit = 20,
  }) async => CursorPage(items: parentCommentId == null ? [_root] : [_reply]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reactions implements ReactionRepository {
  final calls = <(TargetType, int)>[];
  final Future<ReactResult> Function(int)? handler;
  final _liked = <int, bool>{};
  final _counts = {201: 3, 202: 2};

  _Reactions([this.handler]);

  @override
  Future<ReactResult> toggleLike({
    required TargetType targetType,
    required int targetId,
  }) async {
    calls.add((targetType, targetId));
    if (handler != null) return handler!(targetId);
    final next = !(_liked[targetId] ?? false);
    _liked[targetId] = next;
    final count = (_counts[targetId] ?? 0) + (next ? 1 : -1);
    _counts[targetId] = count;
    return ReactResult(myReaction: next ? 'LIKE' : 'NONE', totalCount: count);
  }
}

class _Users implements UserRepository {
  @override
  ProfileModel? get cachedMe => const ProfileModel(userId: 1, fullName: 'An');
  @override
  Future<ProfileModel> getMe() async => cachedMe!;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CommentsCubit _cubit(_Reactions reactions) => CommentsCubit(
  _Comments(),
  reactions: reactions,
  targetType: TargetType.post,
  targetId: 13,
);

Finder _like(int id) => find.descendant(
  of: find.byKey(ValueKey('comment_$id')),
  matching: find.text('Thích'),
);

Finder _count(int id) => find.byKey(ValueKey('comment_reaction_count_$id'));

Widget _app() => BlocProvider(
  create: (_) => ProfileCubit(_Users())..load(),
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showCommentsSheet(
            context,
            targetType: TargetType.post,
            targetId: 13,
          ),
          child: const Text('Mở bình luận'),
        ),
      ),
    ),
  ),
);

void main() {
  test('parse reaction fields, missing fields and deleted comments', () {
    final json = {'comment_id': 1, 'react_count': '7', 'reacted_by_me': true};
    final liked = CommentModel.fromJson(json);
    expect(liked.reactCount, 7);
    expect(liked.reactedByMe, isTrue);
    expect(liked.copyWith(replyCount: 3).reactedByMe, isTrue);
    expect(liked.copyWith(reactedByMe: false).reactedByMe, isFalse);
    final aliases = CommentModel.fromJson({
      'reaction_counts': {'LIKE': 4},
      'my_reaction': 'LIKE',
    });
    expect(aliases.reactCount, 4);
    expect(aliases.reactedByMe, isTrue);
    final missing = CommentModel.fromJson({});
    expect(missing.reactCount, 0);
    expect(missing.reactedByMe, isFalse);
    expect(CommentModel.fromJson({'deleted': true}).hidden, isTrue);
  });

  test(
    'optimistic like, prevent duplicate send, then trust server count',
    () async {
      final pending = Completer<ReactResult>();
      final reactions = _Reactions((_) => pending.future);
      final cubit = _cubit(reactions);
      addTearDown(cubit.close);
      await cubit.load();
      final sending = cubit.toggleLike(_root);
      expect(cubit.state.withReaction(_root).reactCount, 4);
      expect(cubit.state.withReaction(_root).reactedByMe, isTrue);
      expect(cubit.state.reactingIds, {201});
      await cubit.toggleLike(_root);
      expect(reactions.calls, [(TargetType.comment, 201)]);
      pending.complete(const ReactResult(myReaction: 'LIKE', totalCount: 8));
      expect(await sending, isNull);
      expect(cubit.state.withReaction(_root).reactCount, 8);
      expect(cubit.state.reactingIds, isEmpty);
      expect(cubit.state.countDelta, 0);
    },
  );

  test('unlike and reply reactions remain independent', () async {
    final cubit = _cubit(_Reactions());
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.loadReplies(_root);
    await cubit.toggleLike(_root);
    await cubit.toggleLike(_reply);
    await cubit.toggleLike(_root);
    expect(cubit.state.withReaction(_root).reactedByMe, isFalse);
    expect(cubit.state.withReaction(_root).reactCount, 3);
    expect(cubit.state.withReaction(_reply).reactedByMe, isTrue);
    expect(cubit.state.withReaction(_reply).reactCount, 3);
    expect(cubit.state.items.single.replyCount, 1);
    expect(cubit.state.countDelta, 0);
  });

  test(
    'server rejection restores previous reaction and releases button',
    () async {
      var reject = false;
      final reactions = _Reactions((_) async {
        if (reject) {
          throw const ApiException(
            type: ApiErrorType.validation,
            message: 'COMMENT chưa hỗ trợ',
          );
        }
        return const ReactResult(myReaction: 'LIKE', totalCount: 8);
      });
      final cubit = _cubit(reactions);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.toggleLike(_root);
      reject = true;
      expect(await cubit.toggleLike(_root), isA<ApiException>());
      expect(cubit.state.withReaction(_root).reactedByMe, isTrue);
      expect(cubit.state.withReaction(_root).reactCount, 8);
      expect(cubit.state.reactingIds, isEmpty);
    },
  );

  test('hidden/unavailable comments do not send reaction requests', () async {
    final reactions = _Reactions();
    final cubit = _cubit(reactions);
    addTearDown(cubit.close);
    await cubit.toggleLike(_root.copyWith(hidden: true));
    await cubit.toggleLike(const CommentModel(commentId: 1));
    expect(reactions.calls, isEmpty);
  });

  test(
    'leaving the sheet while reaction is pending does not emit after close',
    () async {
      final pending = Completer<ReactResult>();
      final cubit = _cubit(_Reactions((_) => pending.future));
      final sending = cubit.toggleLike(_root);
      await cubit.close();
      pending.complete(const ReactResult(myReaction: 'LIKE', totalCount: 4));
      await expectLater(sending, completes);
    },
  );

  group('UI', () {
    setUp(() async {
      await getIt.reset();
      getIt.registerSingleton<CommentRepository>(_Comments());
    });
    tearDown(getIt.reset);

    testWidgets('root and reply show Like/counts on a narrow phone screen', (
      tester,
    ) async {
      final reactions = _Reactions();
      getIt.registerSingleton<ReactionRepository>(reactions);
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.tap(find.text('Mở bình luận'));
      await tester.pumpAndSettle();
      await tester.tap(_like(201));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(_count(201)).data, '4');
      expect(tester.widget<Text>(_like(201)).style!.color, AppColors.like);
      await tester.tap(_like(201));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(_count(201)).data, '3');
      expect(
        tester.widget<Text>(_like(201)).style!.color,
        AppColors.textSecondary,
      );
      await tester.tap(find.text('Xem 1 phản hồi'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_like(202));
      await tester.tap(_like(202));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(_count(202)).data, '3');
      expect(reactions.calls, [
        (TargetType.comment, 201),
        (TargetType.comment, 201),
        (TargetType.comment, 202),
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('failed like rolls back and shows the server error', (
      tester,
    ) async {
      getIt.registerSingleton<ReactionRepository>(
        _Reactions((_) async {
          throw const ApiException(
            type: ApiErrorType.business,
            message: 'Không thể thích bình luận này',
          );
        }),
      );
      await tester.pumpWidget(_app());
      await tester.tap(find.text('Mở bình luận'));
      await tester.pumpAndSettle();
      await tester.tap(_like(201));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(_count(201)).data, '3');
      expect(
        tester.widget<Text>(_like(201)).style!.color,
        AppColors.textSecondary,
      );
      expect(find.text('Không thể thích bình luận này'), findsOneWidget);
    });

    testWidgets('hidden comment has no reaction button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentTile(
              comment: _root.copyWith(hidden: true),
              onLike: () {},
            ),
          ),
        ),
      );
      expect(find.text('Bình luận này không khả dụng'), findsOneWidget);
      expect(find.text('Thích'), findsNothing);
    });
  });
}
