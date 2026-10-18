import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

enum MediaType {
  image,
  video,
  document;

  static MediaType parse(dynamic v) {
    switch (J.stringOr(v).toUpperCase()) {
      case 'VIDEO':
        return MediaType.video;
      case 'DOCUMENT':
        return MediaType.document;
      default:
        return MediaType.image;
    }
  }

  String get apiValue => name.toUpperCase();
}

/// Một file media đính kèm bài viết (khớp `MediaItem` của backend).
class MediaItem extends Equatable {
  final String? key;
  final String url;
  final MediaType type;
  final int? width;
  final int? height;
  final int? size;

  /// Thời lượng (giây) - chỉ video
  final int? duration;
  final String? name;
  final String? thumbnailUrl;

  const MediaItem({
    this.key,
    required this.url,
    this.type = MediaType.image,
    this.width,
    this.height,
    this.size,
    this.duration,
    this.name,
    this.thumbnailUrl,
  });

  bool get isImage => type == MediaType.image;
  bool get isVideo => type == MediaType.video;

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    key: J.asString(json['key']),
    url: J.stringOr(json['url']),
    type: MediaType.parse(json['type']),
    width: J.asInt(json['width']),
    height: J.asInt(json['height']),
    size: J.asInt(json['size']),
    duration: J.asInt(json['duration']),
    name: J.asString(json['name']),
    thumbnailUrl: J.asString(json['thumbnail_url']),
  );

  /// Backend nhận danh sách `media_urls` là các `MediaItem` đầy đủ.
  Map<String, dynamic> toJson() => {
    if (key != null) 'key': key,
    'url': url,
    'type': type.apiValue,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (size != null) 'size': size,
    if (duration != null) 'duration': duration,
    if (name != null) 'name': name,
    if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
  };

  @override
  List<Object?> get props => [key, url, type, width, height, size, duration];
}

/// Kết quả `POST /medias/upload`.
class MediaUploadResult extends Equatable {
  final String objectKey;
  final String url;
  final int? fileSize;
  final String? contentType;
  final MediaType mediaType;
  final int? width;
  final int? height;

  const MediaUploadResult({
    required this.objectKey,
    required this.url,
    this.fileSize,
    this.contentType,
    this.mediaType = MediaType.image,
    this.width,
    this.height,
  });

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) =>
      MediaUploadResult(
        objectKey: J.stringOr(json['object_key']),
        url: J.stringOr(json['url']),
        fileSize: J.asInt(json['file_size']),
        contentType: J.asString(json['content_type']),
        mediaType: MediaType.parse(json['media_type']),
        width: J.asInt(json['width']),
        height: J.asInt(json['height']),
      );

  /// Chuyển sang [MediaItem] để đính vào bài viết.
  MediaItem toMediaItem() => MediaItem(
    key: objectKey,
    url: url,
    type: mediaType,
    width: width,
    height: height,
    size: fileSize,
  );

  @override
  List<Object?> get props => [objectKey, url];
}
