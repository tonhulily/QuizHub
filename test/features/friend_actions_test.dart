import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/services/social_events.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/data/models/profile_model.dart';
import 'package:quizhub/data/repositories/friend_repository.dart';
import 'package:quizhub/data/repositories/user_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/features/profile/cubit/profile_cubit.dart';
import 'package:quizhub/features/profile/widgets/friend_actions.dart';

class _Backend implements HttpClientAdapter {
  final List<String> calls = [];
  Map<String, dynamic> received = {
    'items': [],
    'pagination': {'has_next': false},
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${o.method} ${o.path}');
    final data = o.path == '/friendships/requests/received'
        ? received
        : o.path == '/friendships/request'
        ? {'status': 'PENDING'}
        : null;
    return ResponseBody.fromString(
      jsonEncode({'code': '0000', 'message': 'ok', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

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

class _FakeUserRepository implements UserRepository {
  final ProfileModel me;
  _FakeUserRepository(this.me);
  @override
  ProfileModel? get cachedMe => me;
  @override
  Future<ProfileModel> getMe() async => me;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Backend backend;

  setUp(() {
    backend = _Backend();
    if (getIt.isRegistered<FriendRepository>()) getIt.reset();
    getIt.registerSingleton<FriendRepository>(
      FriendRepository(
        ApiClient(
          tokens: _Tokens(),
          events: SessionEvents(),
          baseUrl: 'https://example.com/api/v1',
          adapter: backend,
        ),
      ),
    );
    getIt.registerSingleton<SocialEvents>(SocialEvents());
  });

  tearDown(() => getIt.reset());

  Future<void> pump(
    WidgetTester tester, {
    required RelationshipModel rel,
    UserRole theirRole = UserRole.student,
  }) async {
    final me = const ProfileModel(userId: 1, fullName: 'Tôi');
    final meCubit = ProfileCubit(_FakeUserRepository(me));
    await meCubit.load();
    final profile = ProfileModel(
      userId: 5,
      fullName: 'Trần Thị Lan',
      role: theirRole,
      relationships: rel,
    );
    await tester.pumpWidget(
      BlocProvider.value(
        value: meCubit,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: FriendActions(profile: profile),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('stranger: Thêm bạn bè + Theo dõi, tapping sends the request', (
    tester,
  ) async {
    await pump(tester, rel: const RelationshipModel());

    expect(find.text('Thêm bạn bè'), findsOneWidget);
    expect(find.text('Theo dõi'), findsOneWidget);

    await tester.tap(find.text('Thêm bạn bè'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(backend.calls, contains('POST /friendships/request'));
    expect(find.text('Đã gửi lời mời'), findsOneWidget);
    expect(find.text('Thêm bạn bè'), findsNothing);
  });

  testWidgets('friend: shows "Bạn bè" instead of the add button', (
    tester,
  ) async {
    await pump(
      tester,
      rel: const RelationshipModel(
        isFriend: true,
        friendRequestStatus: 'ACCEPTED',
      ),
    );

    expect(find.text('Bạn bè'), findsOneWidget);
    expect(find.text('Thêm bạn bè'), findsNothing);
  });

  testWidgets('incoming request: Xác nhận + Xoá', (tester) async {
    backend.received = {
      'items': [
        {
          'requester': {'user_id': 5, 'full_name': 'Trần Thị Lan'},
        },
      ],
      'pagination': {'has_next': false},
    };
    await pump(
      tester,
      rel: const RelationshipModel(friendRequestStatus: 'PENDING'),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Xác nhận'), findsOneWidget);
    expect(find.text('Xoá'), findsOneWidget);
    expect(find.text('Đã gửi lời mời'), findsNothing);
  });

  testWidgets('request I sent: shows "Đã gửi lời mời"', (tester) async {
    await pump(
      tester,
      rel: const RelationshipModel(friendRequestStatus: 'PENDING'),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Đã gửi lời mời'), findsOneWidget);
    expect(find.text('Xác nhận'), findsNothing);
  });

  testWidgets('different role: no add-friend button, hint + follow only', (
    tester,
  ) async {
    await pump(
      tester,
      rel: const RelationshipModel(),
      theirRole: UserRole.lecturer,
    );

    expect(find.text('Thêm bạn bè'), findsNothing);
    expect(find.text('Theo dõi'), findsOneWidget);
    expect(find.textContaining('cùng vai trò'), findsOneWidget);
  });
}
