import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/data/models/profile_model.dart';
import 'package:quizhub/data/repositories/user_repository.dart';
import 'package:quizhub/features/profile/cubit/profile_cubit.dart';
import 'package:quizhub/features/profile/view/edit_profile_view.dart';

const _withPhotos = ProfileModel(
  userId: 1,
  fullName: 'Nguyễn Văn An',
  avatarUrl: 'https://img/avatar.jpg',
  coverUrl: 'https://img/cover.jpg',
);

/// Kho hồ sơ giả: ghi lại tham số `updateMe`, trả về hồ sơ do bài test quy định.
class _Repo implements UserRepository {
  final ProfileModel initial;

  /// Hồ sơ server trả về sau khi cập nhật (null = áp đúng giá trị đã gửi).
  ProfileModel? serverResponse;

  String? sentAvatar;
  String? sentCover;
  int updates = 0;

  _Repo(this.initial);

  @override
  ProfileModel? get cachedMe => initial;

  @override
  Future<ProfileModel> getMe() async => initial;

  @override
  Future<ProfileModel> updateMe({
    String? fullName,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
    Gender? gender,
    DateTime? dateOfBirth,
    String? timezone,
  }) async {
    updates++;
    sentAvatar = avatarUrl;
    sentCover = coverUrl;
    return serverResponse ??
        ProfileModel(
          userId: initial.userId,
          fullName: fullName ?? initial.fullName,
          avatarUrl: avatarUrl ?? initial.avatarUrl,
          coverUrl: coverUrl ?? initial.coverUrl,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(WidgetTester tester, _Repo repo) async {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  final cubit = ProfileCubit(repo);
  await cubit.load();
  await tester.pumpWidget(
    BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EditProfileView(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('removing the avatar sends an empty avatar_url only', (
    tester,
  ) async {
    final repo = _Repo(_withPhotos);
    await _open(tester, repo);

    await tester.tap(find.byTooltip('Gỡ ảnh đại diện'));
    await tester.pump();
    // Ảnh đại diện đã gỡ nên nút gỡ biến mất; ảnh bìa vẫn còn nút gỡ
    expect(find.byTooltip('Gỡ ảnh đại diện'), findsNothing);
    expect(find.byTooltip('Gỡ ảnh bìa'), findsOneWidget);

    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(repo.updates, 1);
    expect(repo.sentAvatar, '');
    expect(repo.sentCover, isNull); // ảnh bìa không đổi -> không gửi
  });

  testWidgets('removing the cover sends an empty cover_url only', (
    tester,
  ) async {
    final repo = _Repo(_withPhotos);
    await _open(tester, repo);

    await tester.tap(find.byTooltip('Gỡ ảnh bìa'));
    await tester.pump();
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(repo.sentCover, '');
    expect(repo.sentAvatar, isNull);
  });

  testWidgets('saving without touching photos sends neither photo', (
    tester,
  ) async {
    final repo = _Repo(_withPhotos);
    await _open(tester, repo);

    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();

    expect(repo.updates, 1);
    expect(repo.sentAvatar, isNull);
    expect(repo.sentCover, isNull);
  });

  testWidgets('profile without photos has no remove buttons', (tester) async {
    final repo = _Repo(
      const ProfileModel(userId: 1, fullName: 'Nguyễn Văn An'),
    );
    await _open(tester, repo);

    expect(find.byTooltip('Gỡ ảnh đại diện'), findsNothing);
    expect(find.byTooltip('Gỡ ảnh bìa'), findsNothing);
  });

  testWidgets('if the server ignores the removal the user is told', (
    tester,
  ) async {
    final repo = _Repo(_withPhotos)
      // Server bỏ qua chuỗi rỗng và trả lại ảnh cũ
      ..serverResponse = _withPhotos;
    await _open(tester, repo);

    await tester.tap(find.byTooltip('Gỡ ảnh đại diện'));
    await tester.pump();
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('chưa cho phép gỡ ảnh đại diện'),
      findsOneWidget,
    );
    // Vẫn ở lại màn chỉnh sửa và khôi phục ảnh theo server
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(find.byTooltip('Gỡ ảnh đại diện'), findsOneWidget);
  });
}
