import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/design_system/component_tokens.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/response_codes.dart';
import '../../core/utils/json_utils.dart';
import '../models/media_item.dart';

/// Mục đích upload (query `purpose` của /medias/upload).
enum MediaPurpose {
  avatar,
  cover,
  question,
  post,
  comment,
  chat,
  document;

  String get apiValue => name.toUpperCase();
}

/// Upload ảnh/video: `POST /medias/upload`.
///
/// Validate phía client TRƯỚC khi gọi API (yêu cầu phi chức năng):
/// ảnh tối đa 4MB, không nhận ảnh động (GIF).
class MediaRepository {
  static const int maxVideoBytes = 15 * 1024 * 1024;

  final ApiClient _api;

  MediaRepository(this._api);

  Future<MediaUploadResult> uploadImage(
    File file, {
    required MediaPurpose purpose,
    void Function(int sent, int total)? onProgress,
  }) async {
    final name = file.path.split(Platform.pathSeparator).last;
    final lower = name.toLowerCase();
    if (lower.endsWith('.gif')) {
      throw const ApiException(
        type: ApiErrorType.validation,
        code: ResponseCodes.invalidParameterValue,
        message: 'Ứng dụng không hỗ trợ ảnh động (GIF).',
      );
    }
    final size = await file.length();
    if (size > ComponentTokens.maxImageSizeBytes) {
      throw const ApiException(
        type: ApiErrorType.validation,
        code: ResponseCodes.fileSizeExceeded,
        message: 'Ảnh vượt quá dung lượng tối đa 4MB.',
      );
    }
    return _upload(file, name, purpose, onProgress);
  }

  Future<MediaUploadResult> uploadVideo(
    File file, {
    required MediaPurpose purpose,
    void Function(int sent, int total)? onProgress,
  }) async {
    final name = file.path.split(Platform.pathSeparator).last;
    final size = await file.length();
    if (size > maxVideoBytes) {
      throw const ApiException(
        type: ApiErrorType.validation,
        code: ResponseCodes.fileSizeExceeded,
        message: 'Video vượt quá dung lượng tối đa 15MB.',
      );
    }
    return _upload(file, name, purpose, onProgress);
  }

  Future<MediaUploadResult> _upload(
    File file,
    String name,
    MediaPurpose purpose,
    void Function(int, int)? onProgress,
  ) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: name),
    });
    return _api.upload<MediaUploadResult>(
      ApiEndpoints.mediaUpload,
      formData: form,
      query: {'purpose': purpose.apiValue},
      onProgress: onProgress,
      parser: (d) => MediaUploadResult.fromJson(J.asMap(d) ?? const {}),
    );
  }
}
