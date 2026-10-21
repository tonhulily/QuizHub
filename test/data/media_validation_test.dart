import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/data/models/media_item.dart';
import 'package:quizhub/data/repositories/media_repository.dart';

class _UploadApi implements ApiClient {
  final calls = <({String path, String? purpose, String? filename})>[];

  @override
  Future<T> upload<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? query,
    required JsonParser<T> parser,
    void Function(int sent, int total)? onProgress,
  }) async {
    calls.add((
      path: path,
      purpose: query?['purpose'] as String?,
      filename: formData.files.single.value.filename,
    ));
    return parser({
      'object_key': 'test/file',
      'url': 'https://example.com/file',
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;
  late _UploadApi api;
  late MediaRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('quizhub-media-test-');
    api = _UploadApi();
    repository = MediaRepository(api);
  });

  tearDown(() => temp.delete(recursive: true));

  Future<File> fileOfSize(String name, int bytes) async {
    final file = File('${temp.path}${Platform.pathSeparator}$name');
    final handle = await file.open(mode: FileMode.write);
    try {
      await handle.truncate(bytes);
    } finally {
      await handle.close();
    }
    return file;
  }

  for (final name in ['animation.gif', 'animation.GIF']) {
    test('Ảnh $name bị từ chối trước khi gọi API', () async {
      final file = await fileOfSize(name, 10);

      await expectLater(
        repository.uploadImage(file, purpose: MediaPurpose.post),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', '1004')),
      );
      expect(api.calls, isEmpty);
    });
  }

  for (final video in [false, true]) {
    final label = video ? 'Video' : 'Ảnh';
    final name = video ? 'clip.mp4' : 'photo.jpg';
    final limit = (video ? 15 : 4) * 1024 * 1024;

    Future<MediaUploadResult> upload(File file) => video
        ? repository.uploadVideo(file, purpose: MediaPurpose.post)
        : repository.uploadImage(file, purpose: MediaPurpose.post);

    test('$label đúng giới hạn được chuyển tới API upload', () async {
      final file = await fileOfSize(name, limit);

      final result = await upload(file);

      expect(api.calls, [
        (path: '/medias/upload', purpose: 'POST', filename: name),
      ]);
      expect(result.objectKey, 'test/file');
    });

    test('$label vượt giới hạn 1 byte bị chặn trước API', () async {
      final file = await fileOfSize(name, limit + 1);

      await expectLater(
        upload(file),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', '1006')),
      );
      expect(api.calls, isEmpty);
    });
  }
}
