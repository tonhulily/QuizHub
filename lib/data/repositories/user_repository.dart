import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/storage/credential_storage.dart';
import '../../core/storage/local_storage.dart';
import '../../core/utils/json_utils.dart';
import '../models/profile_model.dart';

/// Hồ sơ người dùng: `/users/me`, `/users/{id}`.
class UserRepository {
  final ApiClient _api;
  final LocalStorage _storage;
  final CredentialStorage _credentials;

  UserRepository(this._api, this._storage, this._credentials);

  /// Hồ sơ cache gần nhất (hiển thị ngay khi mở app, trước khi gọi API).
  ProfileModel? get cachedMe {
    final json = _storage.cachedUser;
    return json == null ? null : ProfileModel.fromJson(json);
  }

  /// `GET /users/me`
  Future<ProfileModel> getMe() async {
    final me = await _api.get<ProfileModel>(
      ApiEndpoints.me,
      parser: (d) => ProfileModel.fromJson(J.asMap(d) ?? const {}),
    );
    await _storage.setCachedUser(me.toJson());
    // Thẻ "tài khoản đã lưu" ở màn Đăng nhập hiển thị đúng tên / ảnh mới nhất
    if ((me.email ?? '').isNotEmpty) {
      await _credentials.updateProfile(
        email: me.email!,
        fullName: me.fullName,
        avatarUrl: me.avatarUrl,
      );
    }
    return me;
  }

  /// `GET /users/{id}`
  Future<ProfileModel> getUser(int userId) => _api.get<ProfileModel>(
    ApiEndpoints.user(userId),
    parser: (d) => ProfileModel.fromJson(J.asMap(d) ?? const {}),
  );

  /// `PUT /users/me` - chỉ gửi những field có giá trị.
  Future<ProfileModel> updateMe({
    String? fullName,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
    Gender? gender,
    DateTime? dateOfBirth,
    String? timezone,
  }) async {
    final body = <String, dynamic>{
      'full_name': ?fullName,
      'avatar_url': ?avatarUrl,
      'cover_url': ?coverUrl,
      'bio': ?bio,
      'gender': ?gender?.apiValue,
      if (dateOfBirth != null)
        'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'timezone': ?timezone,
    };
    final me = await _api.put<ProfileModel>(
      ApiEndpoints.me,
      body: body,
      parser: (d) => ProfileModel.fromJson(J.asMap(d) ?? const {}),
    );
    await _storage.setCachedUser(me.toJson());
    return me;
  }
}
