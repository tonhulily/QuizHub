import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/user_repository.dart';

enum ProfileStatus { initial, loading, loaded, failure }

class ProfileState extends Equatable {
  final ProfileStatus status;
  final ProfileModel? profile;
  final ApiException? error;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.error,
  });

  bool get hasProfile => profile != null;

  ProfileState copyWith({
    ProfileStatus? status,
    ProfileModel? profile,
    ApiException? error,
    bool clearError = false,
  }) => ProfileState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [status, profile, error];
}

/// Hồ sơ của CHÍNH MÌNH - dùng toàn app (Home, Profile, Post composer...).
///
/// Cung cấp ở gốc cây widget: `context.read<ProfileCubit>().state.profile`.
class ProfileCubit extends Cubit<ProfileState> {
  final UserRepository _repo;

  ProfileCubit(this._repo) : super(const ProfileState());

  /// Nạp hồ sơ từ cache (nếu có) để hiển thị ngay, sau đó gọi API làm mới.
  Future<void> load({bool silent = false}) async {
    final cached = state.profile ?? _repo.cachedMe;
    if (cached != null) {
      emit(state.copyWith(status: ProfileStatus.loaded, profile: cached));
    } else if (!silent) {
      emit(state.copyWith(status: ProfileStatus.loading, clearError: true));
    }
    try {
      final me = await _repo.getMe();
      emit(ProfileState(status: ProfileStatus.loaded, profile: me));
    } on ApiException catch (e) {
      // Có cache thì vẫn giữ hiển thị, chỉ báo lỗi
      emit(
        state.copyWith(
          status: state.hasProfile
              ? ProfileStatus.loaded
              : ProfileStatus.failure,
          error: e,
        ),
      );
    }
  }

  /// Cập nhật hồ sơ. Ném [ApiException] để màn hình tự hiển thị lỗi.
  Future<ProfileModel> update({
    String? fullName,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
    Gender? gender,
    DateTime? dateOfBirth,
  }) async {
    final updated = await _repo.updateMe(
      fullName: fullName,
      avatarUrl: avatarUrl,
      coverUrl: coverUrl,
      bio: bio,
      gender: gender,
      dateOfBirth: dateOfBirth,
    );
    emit(ProfileState(status: ProfileStatus.loaded, profile: updated));
    return updated;
  }

  void clear() => emit(const ProfileState());
}
