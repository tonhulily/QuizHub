import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/data/models/profile_model.dart';
import 'package:quizhub/data/repositories/user_repository.dart';
import 'package:quizhub/features/profile/cubit/profile_cubit.dart';
import 'package:quizhub/features/profile/view/about_profile_view.dart';
import 'package:quizhub/features/profile/view/edit_profile_view.dart';
import 'package:quizhub/features/profile/widgets/profile_header.dart';

final _me = ProfileModel(
  userId: 1,
  email: 'an.nv210001@sis.hust.edu.vn',
  fullName: 'Nguyễn Văn An',
  gender: Gender.male,
  dateOfBirth: DateTime(2004, 8, 5),
  bio: 'Sinh viên K66',
  schoolFaculty: 'Trường CNTT&TT',
  major: 'Khoa học máy tính',
  className: 'KHMT 02 - K66',
  studentLecturerCode: '20210001',
  totalProposedQuestions: 12,
  gamificationPoints: 340,
  badgesCount: 3,
  friendsCount: 128,
  createdAt: DateTime(2025, 9, 5),
);

class _FakeUserRepository implements UserRepository {
  final ProfileModel profile;
  _FakeUserRepository(this.profile);

  @override
  ProfileModel? get cachedMe => profile;

  @override
  Future<ProfileModel> getMe() async => profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpEdit(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  final cubit = ProfileCubit(_FakeUserRepository(_me));
  await cubit.load();
  await tester.pumpWidget(
    BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const EditProfileView(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Edit profile: birthday is marked "Chỉ mình bạn", name public', (
    tester,
  ) async {
    await _pumpEdit(tester);

    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Ngày sinh'), findsOneWidget);
    expect(find.text('Chỉ mình bạn'), findsWidgets);
    expect(find.text('Mọi người'), findsWidgets);
    expect(
      find.textContaining('Ngày sinh chỉ mình bạn nhìn thấy'),
      findsOneWidget,
    );
  });

  testWidgets('Edit profile lists read-only info shown on the profile page', (
    tester,
  ) async {
    await _pumpEdit(tester);

    // Thông tin nhà trường cấp
    expect(find.text('Mã số SV/GV'), findsOneWidget);
    expect(find.text('20210001'), findsOneWidget);
    expect(find.text('Khoa / Viện'), findsOneWidget);
    expect(find.text('Chuyên ngành'), findsOneWidget);
    expect(find.text('Lớp'), findsOneWidget);
    // Tài khoản
    expect(find.text('an.nv210001@sis.hust.edu.vn'), findsOneWidget);
    expect(find.text('Ngày tham gia'), findsOneWidget);
    // Hoạt động tự tính
    expect(find.text('Điểm tích luỹ'), findsOneWidget);
    expect(find.text('Câu hỏi đã đề xuất'), findsOneWidget);
    expect(find.text('Huy hiệu'), findsOneWidget);
    // Giải thích về quyền riêng tư
    expect(
      find.textContaining('Máy chủ chỉ trả ngày sinh và email'),
      findsOneWidget,
    );
  });

  Future<void> pumpHeader(WidgetTester tester, ProfileModel profile) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(child: ProfileHeader(profile: profile)),
        ),
      ),
    );
  }

  testWidgets('Profile header: compact detail lines + "see more" button', (
    tester,
  ) async {
    await pumpHeader(tester, _me);

    expect(find.text('Chi tiết'), findsOneWidget);
    expect(find.textContaining('Học tại'), findsOneWidget);
    expect(find.textContaining('Mã SV/GV'), findsOneWidget);
    expect(find.textContaining('Tham gia'), findsOneWidget);
    expect(find.text('Xem thông tin giới thiệu'), findsOneWidget);
    // Thông tin riêng tư / chi tiết chỉ nằm ở trang Giới thiệu, không có
    // khung từng ô trên trang cá nhân
    expect(find.text('Ngày sinh'), findsNothing);
    expect(find.text('Giới tính'), findsNothing);
    expect(find.text('Điểm tích luỹ'), findsNothing);
  });

  testWidgets('Profile header of another user has no birthday', (tester) async {
    await pumpHeader(
      tester,
      const ProfileModel(
        userId: 2,
        fullName: 'Trần Thị Lan',
        gender: Gender.female,
      ),
    );

    expect(find.text('Xem thông tin giới thiệu'), findsOneWidget);
    expect(find.textContaining('Sinh ngày'), findsNothing);
    expect(find.text('Ngày sinh'), findsNothing);
  });

  Future<void> pumpAbout(WidgetTester tester, ProfileModel profile) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final cubit = ProfileCubit(_FakeUserRepository(_me));
    await cubit.load();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: AboutProfileView(profile: profile),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('About page of my profile shows everything incl. birthday', (
    tester,
  ) async {
    await pumpAbout(tester, _me);

    expect(find.text('Điểm tích luỹ'), findsOneWidget);
    expect(find.text('Bạn bè'), findsOneWidget);
    expect(find.text('Người theo dõi'), findsOneWidget);
    expect(find.text('Đang theo dõi'), findsOneWidget);
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Giới tính'), findsOneWidget);
    expect(find.text('Nam'), findsOneWidget);
    expect(find.text('Ngày sinh'), findsOneWidget);
    expect(find.text('05/08/2004'), findsOneWidget);
    // Ngày sinh và email có biểu tượng khoá (chỉ mình bạn thấy)
    expect(find.byTooltip('Chỉ mình bạn thấy'), findsNWidgets(2));
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('an.nv210001@sis.hust.edu.vn'), findsOneWidget);
    expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
  });

  testWidgets('About page of another user hides birthday, email and edit', (
    tester,
  ) async {
    await pumpAbout(
      tester,
      const ProfileModel(
        userId: 2,
        fullName: 'Trần Thị Lan',
        gender: Gender.female,
        studentLecturerCode: '20230002',
      ),
    );

    expect(find.text('Trần Thị Lan'), findsOneWidget);
    expect(find.text('Nữ'), findsOneWidget);
    expect(find.text('20230002'), findsOneWidget);
    expect(find.text('Ngày sinh'), findsNothing);
    expect(find.text('Tài khoản'), findsNothing);
    expect(find.text('Chỉnh sửa hồ sơ'), findsNothing);
  });
}
