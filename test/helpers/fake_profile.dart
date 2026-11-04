import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/data/models/profile_model.dart';
import 'package:quizhub/data/repositories/user_repository.dart';
import 'package:quizhub/features/profile/cubit/profile_cubit.dart';

/// Người dùng đang đăng nhập với vai trò [role] (không gọi mạng).
class FakeUsers implements UserRepository {
  final ProfileModel me;

  FakeUsers(UserRole role)
    : me = ProfileModel(userId: 1, fullName: 'Người dùng thử', role: role);

  @override
  ProfileModel? get cachedMe => me;

  @override
  Future<ProfileModel> getMe() async => me;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Bọc [child] bằng `ProfileCubit` như ở gốc app, đã nạp sẵn hồ sơ có [role].
///
/// Key theo [role]: `pumpWidget` lại với vai trò khác thì provider được dựng
/// lại (không có key, Flutter giữ cubit cũ và vai trò không đổi).
Widget withRole(UserRole role, Widget child) => BlocProvider(
  key: ValueKey(role),
  create: (_) => ProfileCubit(FakeUsers(role))..load(),
  child: child,
);
