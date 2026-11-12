import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:quizhub/dev/preview_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/local_storage.dart';
import '../core/storage/token_storage.dart';
import '../core/services/blocked_users.dart';
import '../core/network/api_exception.dart';
import 'preview_qbank.dart';
import 'preview_search.dart';
import 'preview_notifications.dart';

/// Token giả để vào thẳng app mà không cần đăng nhập (chỉ dùng cho preview).
class PreviewTokens extends TokenStorage {
  String? _a = 'preview-access';
  String? _r = 'preview-refresh';

  @override
  String? get accessToken => _a;
  @override
  String? get refreshToken => _r;
  @override
  bool get hasTokens => true;
  @override
  Future<void> load() async {}
  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _a = accessToken;
    _r = refreshToken;
  }

  @override
  Future<void> clear() async {
    _a = null;
    _r = null;
  }
}

/// Backend giả (trả dữ liệu mẫu) để xem & phát triển giao diện khi chưa có
/// tài khoản / mạng tới server. Chạy: `flutter run -t lib/main_preview.dart`.
///
/// Bài viết, reaction bình luận, quan hệ xã hội và chat được lưu trên máy khi truyền
/// [preferences]; dữ liệu khác nằm trong RAM. Không truyền kho lưu trữ khi
/// dùng làm fixture cho unit test.
class PreviewBackend implements HttpClientAdapter {
  static const _postsKey = 'preview_posts_v1';
  static const _relationshipsKey = 'preview_relationships_v1';
  static const _commentReactionsKey = 'preview_comment_reactions_v1';
  final SharedPreferences? _preferences;
  final Map<int, Map<String, dynamic>> _commentReactions = {};
  int _nextCommentId = 1000000000;
  Future<void> _pendingRequest = Future<void>.value();

  /// Vai trò người dùng mẫu. Thử nhánh của giảng viên (Đề thi...):
  /// `flutter run -t lib/main_preview.dart --dart-define=PREVIEW_ROLE=LECTURER`
  static const _role = String.fromEnvironment(
    'PREVIEW_ROLE',
    defaultValue: 'STUDENT',
  );

  static const _me = {
    'user_id': 1,
    'email': 'an.nv210001@sis.hust.edu.vn',
    'full_name': 'Nguyễn Văn An',
    'avatar_url': 'https://i.pravatar.cc/300?img=12',
    'cover_url': 'https://picsum.photos/seed/quizhub-cover/1000/500',
    'bio': 'Sinh viên CNTT K66 · thích Cấu trúc dữ liệu & giải thuật',
    'school_faculty': 'Trường Công nghệ Thông tin và Truyền thông',
    'major': 'Khoa học máy tính',
    'class_name': 'KHMT 02 - K66',
    'student_lecturer_code': '20210001',
    'role': _role,
    'profile_completed': true,
    'verified': true,
    'total_proposed_questions': 12,
    'gamification_points': 340,
    'badges_count': 3,
    'friends_count': 128,
    'followers_count': 54,
    'following_count': 31,
    'created_at': '2025-09-05T08:00:00Z',
  };

  static const _lan = {
    'user_id': 2,
    'full_name': 'Trần Thị Lan',
    'avatar_url': 'https://i.pravatar.cc/150?img=47',
  };
  static const _minh = {
    'user_id': 3,
    'full_name': 'ThS. Lê Quang Minh',
    'avatar_url': 'https://i.pravatar.cc/150?img=33',
  };

  /// Người dùng mẫu (id 2..) cho tìm kiếm / gợi ý / bạn bè. Id 3 là giảng viên.
  static const _names = [
    'Trần Thị Lan',
    'ThS. Lê Quang Minh',
    'Phạm Đức Anh',
    'Nguyễn Hoàng Long',
    'Vũ Ngọc Tùng',
    'Đỗ Khánh Linh',
    'Hoàng Gia Bảo',
    'Bùi Thanh Hà',
    'Ngô Minh Quân',
    'Đặng Thu Trang',
    'Lý Tuấn Kiệt',
    'Trương Mai Phương',
  ];

  Map<String, dynamic> _person(int id) {
    final i = (id - 2) % _names.length;
    final lecturer = id == 3;
    return {
      'user_id': id,
      'full_name': id < 2 + _names.length ? _names[i] : '${_names[i]} $id',
      'student_lecturer_code': '2023${5000 + id}',
      'email': 'user$id@sis.hust.edu.vn',
      'bio': 'Người dùng mẫu số $id',
      'avatar_url': 'https://i.pravatar.cc/150?img=${(id * 7) % 70}',
      'avatar_frame_url': '',
      'school_faculty': 'Trường Công nghệ Thông tin và Truyền thông',
      'major': 'Khoa học máy tính',
      'role': lecturer ? 'LECTURER' : 'STUDENT',
    };
  }

  static const _totalUsers = 40;
  final Set<int> _friendIds = {2, 4};
  final Set<int> _sentTo = {7};
  final Set<int> _receivedFrom = {5, 6};
  final Set<int> _following = {};
  final Set<int> _blocked = {};
  final Set<int> _followers = {2, 4, 5};
  final Map<int, int> _commentAuthors = {};
  final Map<int, int> _commentParents = {};
  final Map<int, int> _commentPostOwners = {};

  final Map<int, Map<String, dynamic>> _posts = {};
  final Map<String, bool> _liked = {};
  int _nextId = 100;

  /// Module Ngân hàng câu hỏi + Đề thi + AI (dữ liệu mẫu riêng).
  final PreviewQbank _qbank = PreviewQbank();

  final PreviewSearch _search = PreviewSearch();

  /// Module thông báo (danh sách, đánh dấu đã đọc) dùng dữ liệu RAM.
  final PreviewNotifications _notifications = PreviewNotifications();

  /// Cấu hình thông báo mẫu cho màn hình Push Settings.
  /// Dữ liệu thay đổi khi PUT và được giữ trong RAM trong phiên preview.
  Map<String, dynamic> _pushSettings = {
    'push_enabled': true,
    'categories': {
      'SOCIAL': {
        'enabled': true,
        'description': 'Lời mời kết bạn, người theo dõi và tương tác xã hội.',
      },
      'GAMIFICATION': {
        'enabled': true,
        'description': 'Điểm thưởng, huy hiệu và bảng xếp hạng.',
      },
      'ACADEMIC': {
        'enabled': false,
        'description': 'Thông báo về câu hỏi, đề thi và hoạt động học tập.',
      },
      'SYSTEM': {
        'enabled': true,
        'description': 'Thông báo hệ thống và cập nhật quan trọng.',
      },
    },
    'quiet_hours': {
      'enabled': true,
      'start_time': '22:00',
      'end_time': '07:00',
    },
    'sound_enabled': true,
    'vibration_enabled': false,
  };

  late final PreviewChat chat = PreviewChat(
    person: _person,
    me: _me,
    isBlocked: _blocked.contains,
    preferences: _preferences,
  );

  PreviewBackend({SharedPreferences? preferences})
    : _preferences = preferences {
    String ago(int minutes) => DateTime.now()
        .toUtc()
        .subtract(Duration(minutes: minutes))
        .toIso8601String();
    Map<String, dynamic> img(String seed, int w, int h) => {
      'url': 'https://picsum.photos/seed/$seed/$w/$h',
      'type': 'IMAGE',
      'width': w,
      'height': h,
    };

    _posts[11] = {
      'post_id': 11,
      'content':
          'Mọi người cho mình hỏi bài tập 3 môn Cấu trúc dữ liệu và giải thuật '
          'với! Cây AVL khi xoá một nút có hai con thì chọn nút thay thế là '
          'tiền nhiệm hay kế nhiệm sẽ ít phải cân bằng lại hơn ạ? '
          'Mình thử cả hai cách nhưng số lần xoay không giống nhau.',
      'post_type': 'SOCIAL_POST',
      'visibility': 'PUBLIC',
      'author': _lan,
      'react_count': 12,
      'comment_count': 4,
      'reacted_by_me': false,
      'created_at': ago(25),
      'updated_at': ago(25),
      'subject_code': 'IT3011',
      'subject_name': 'Cấu trúc dữ liệu và giải thuật',
    };
    _posts[12] = {
      'post_id': 12,
      'content': 'Ảnh sơ đồ cây mình vẽ khi ôn tập, ai cần thì lấy nhé 📚',
      'post_type': 'SOCIAL_POST',
      'visibility': 'FRIENDS',
      'media_urls': [img('tree1', 1200, 800)],
      'author': _me,
      'react_count': 3,
      'comment_count': 0,
      'reacted_by_me': true,
      'created_at': ago(180),
      'updated_at': ago(180),
    };
    _posts[13] = {
      'post_id': 13,
      'content': 'Thư viện Tạ Quang Bửu mùa thi 🌿',
      'post_type': 'SOCIAL_POST',
      'visibility': 'PUBLIC',
      'media_urls': [
        img('lib1', 800, 800),
        img('lib2', 800, 800),
        img('lib3', 800, 800),
        img('lib4', 800, 800),
        img('lib5', 800, 800),
      ],
      'author': _minh,
      'react_count': 1240,
      'comment_count': 58,
      'reacted_by_me': false,
      'created_at': ago(60 * 26),
      'updated_at': ago(60 * 26),
      'lecturer_note': 'Các em nhớ ôn kỹ chương cây nhị phân tìm kiếm nhé.',
      'noted_lecturer': _minh,
    };
    _restorePosts();
    _restoreRelationships();
    _restoreCommentReactions();
    if (preferences != null) {
      // Trước khi preview có lưu trữ, ID đã xoá vẫn được LocalStorage nhớ lại.
      // Không cấp lại các ID đó, nếu không bài mới sẽ bị bộ lọc xoá ẩn đi.
      for (final id in LocalStorage(preferences).deletedPostIds) {
        _posts.remove(id);
        if (id >= _nextId) _nextId = id + 1;
      }
    }
  }

  Map<String, dynamic> _postSnapshot() => {
    'version': 1,
    'next_id': _nextId,
    'posts': _posts.values.toList(),
  };

  Map<String, dynamic> _relationshipSnapshot() => {
    'version': 1,
    'friends': _friendIds.toList(),
    'sent': _sentTo.toList(),
    'received': _receivedFrom.toList(),
    'following': _following.toList(),
    'followers': _followers.toList(),
    'blocked': _blocked.toList(),
  };

  void _applyRelationships(Map<String, dynamic> data) {
    if (data['version'] != 1) return;
    final sets = <String, Set<int>>{
      'friends': _friendIds,
      'sent': _sentTo,
      'received': _receivedFrom,
      'following': _following,
      'followers': _followers,
      'blocked': _blocked,
    };
    if (sets.keys.any(
      (key) =>
          data[key] is! List ||
          (data[key] as List).any((id) => id is! int || id <= 1),
    )) {
      return;
    }
    for (final entry in sets.entries) {
      entry.value
        ..clear()
        ..addAll((data[entry.key] as List).cast<int>());
    }
    for (final id in _blocked) {
      for (final entry in sets.entries.where((e) => e.key != 'blocked')) {
        entry.value.remove(id);
      }
    }
  }

  void _restoreRelationships() {
    final raw = _preferences?.get(_relationshipsKey);
    if (raw is! String) return;
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) _applyRelationships(value);
    } on FormatException {
      // Dùng quan hệ mẫu nếu dữ liệu cục bộ bị hỏng.
    }
  }

  bool _changesRelationships(RequestOptions options) =>
      const ['POST', 'DELETE'].contains(options.method) &&
      (options.path.startsWith('/blocks/') ||
          options.path.startsWith('/friendships/') ||
          (options.path.startsWith('/follows/') &&
              !const [
                '/follows/following',
                '/follows/followers',
              ].contains(options.path)));

  void _requireVisible(int? id) {
    if (_blocked.contains(id)) throw BlockedUsers.unavailable;
  }

  Map<String, dynamic> _visiblePost(Map<String, dynamic> post) => {
    ...post,
    if (_blocked.contains((post['noted_lecturer'] as Map?)?['user_id'])) ...{
      'lecturer_note': null,
      'noted_lecturer': null,
    },
  };

  Map<String, dynamic> _visibleComment(Map<String, dynamic> comment) {
    final id = comment['comment_id'] as int;
    final author = (comment['author'] as Map?)?['user_id'] as int?;
    if (author != null) _commentAuthors[id] = author;
    final parent = comment['parent_comment_id'];
    if (parent is int) _commentParents[id] = parent;
    if (comment['target_type'] == 'POST') {
      final owner =
          (_posts[int.tryParse('${comment['target_id']}')]?['author']
              as Map?)?['user_id'];
      if (owner is int) _commentPostOwners[id] = owner;
    }
    if (_blocked.contains(author)) {
      return {
        ...comment,
        'author': null,
        'content': null,
        'media_url': null,
        'hidden': true,
        'reply_count': 0,
        'react_count': 0,
        'reacted_by_me': false,
      };
    }
    return comment;
  }

  void _requireCommentVisible(int id) {
    _requireVisible(_commentAuthors[id]);
    _requireVisible(_commentAuthors[_commentParents[id]]);
    _requireVisible(_commentPostOwners[id]);
  }

  void _restoreCommentReactions() {
    final raw = _preferences?.get(_commentReactionsKey);
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final restored = <int, Map<String, dynamic>>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key);
        final fields = entry.value;
        if (id == null ||
            id <= 0 ||
            fields is! Map<String, dynamic> ||
            fields['reacted_by_me'] is! bool ||
            fields['react_count'] is! int ||
            (fields['react_count'] as int) < 0) {
          return;
        }
        restored[id] = fields;
      }
      _commentReactions.addAll(restored);
      for (final id in restored.keys) {
        if (id >= _nextCommentId) _nextCommentId = id + 1;
      }
    } on FormatException {
      // Bỏ qua dữ liệu demo hỏng; lần tương tác tiếp theo sẽ lưu lại.
    }
  }

  String _encodedCommentReactions() => jsonEncode({
    for (final entry in _commentReactions.entries) '${entry.key}': entry.value,
  });

  Map<String, dynamic> _commentReactionFields(int id) =>
      _commentReactions[id] ?? {'reacted_by_me': false, 'react_count': 0};

  // ID mẫu riêng cho mỗi bài/phiên/câu hỏi, để like một nơi không lan sang nơi
  // khác. Bình luận tạo mới dùng dải ID riêng, tăng tiếp sau ID đã lưu reaction.
  int _sampleCommentId(Map<String, dynamic> query, int slot) {
    final targetId = int.tryParse('${query['target_id']}') ?? 0;
    final type = switch (query['target_type']) {
      'SESSION' => 1,
      'QUESTION' => 2,
      _ => 0,
    };
    return (targetId * 3 + type) * 3 + slot;
  }

  Future<ResponseBody> _reactToComment(Map body) async {
    final id = int.tryParse('${body['target_id']}');
    if (id == null || id <= 0) {
      return _response(
        null,
        status: 400,
        code: '1003',
        message: 'ID bình luận không hợp lệ.',
      );
    }
    try {
      _requireCommentVisible(id);
    } on ApiException catch (e) {
      return _response(
        null,
        status: 403,
        code: e.code ?? '1009',
        message: e.message,
      );
    }
    final before = _commentReactions[id];
    final current = _commentReactionFields(id);
    final liked = current['reacted_by_me'] != true;
    final count = ((current['react_count'] as int) + (liked ? 1 : -1)).clamp(
      0,
      1 << 30,
    );
    _commentReactions[id] = {'reacted_by_me': liked, 'react_count': count};
    final preferences = _preferences;
    if (preferences != null) {
      try {
        if (!await preferences.setString(
          _commentReactionsKey,
          _encodedCommentReactions(),
        )) {
          throw StateError('Could not save preview comment reaction');
        }
      } catch (_) {
        if (before == null) {
          _commentReactions.remove(id);
        } else {
          _commentReactions[id] = before;
        }
        try {
          await preferences.setString(
            _commentReactionsKey,
            _encodedCommentReactions(),
          );
        } catch (_) {
          // Trả lỗi; UI sẽ hoàn tác lượt thích vừa bấm.
        }
        return _response(
          null,
          status: 500,
          code: '1001',
          message: 'Không thể lưu lượt thích trên máy. Vui lòng thử lại.',
        );
      }
    }
    return _response({
      'my_reaction': liked ? 'LIKE' : 'NONE',
      'total_count': count,
    });
  }

  void _restorePosts() {
    final raw = _preferences?.get(_postsKey);
    if (raw is! String) return;
    try {
      final snapshot = jsonDecode(raw);
      if (snapshot is! Map<String, dynamic> || snapshot['version'] != 1) return;
      final rows = snapshot['posts'];
      if (rows is! List) return;
      final restored = <int, Map<String, dynamic>>{};
      var nextId = 100;
      for (final row in rows) {
        if (row is! Map<String, dynamic>) return;
        final id = row['post_id'];
        if (id is! int ||
            id <= 0 ||
            restored.containsKey(id) ||
            row['content'] is! String ||
            row['author'] is! Map<String, dynamic>) {
          return;
        }
        restored[id] = row;
        if (id >= nextId) nextId = id + 1;
      }
      final storedNext = snapshot['next_id'];
      if (storedNext is int && storedNext > nextId) nextId = storedNext;
      // Thay toàn bộ tập bài, kể cả tập rỗng, để bài đã xoá không xuất hiện lại.
      _posts
        ..clear()
        ..addAll(restored);
      _nextId = nextId;
    } on FormatException {
      // Dữ liệu cục bộ hỏng: dùng bộ mẫu, không làm app kẹt ở màn khởi động.
    }
  }

  bool _changesPosts(RequestOptions o) =>
      (o.path == '/posts' && o.method == 'POST') ||
      (RegExp(r'^/posts/\d+$').hasMatch(o.path) &&
          (o.method == 'PUT' || o.method == 'DELETE'));

  static ResponseBody _response(
    dynamic data, {
    int status = 200,
    String code = '0000',
    String message = 'OK',
  }) => ResponseBody.fromString(
    jsonEncode({'code': code, 'message': message, 'data': data}),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  Future<ResponseBody> _respond(RequestOptions options) async {
    if (PreviewChat.handles(options.method, options.path)) {
      try {
        return _response(
          await chat.handle(
            options.method,
            options.path,
            options.queryParameters,
            options.data is Map
                ? Map<String, dynamic>.from(options.data as Map)
                : {},
          ),
        );
      } on ApiException catch (e) {
        return _response(
          null,
          status: e.statusCode ?? 500,
          code: e.code ?? '1001',
          message: e.message,
        );
      }
    }
    if (options.path == '/react' &&
        options.method == 'POST' &&
        options.data is Map &&
        options.data['target_type'] == 'COMMENT') {
      return _reactToComment(options.data as Map);
    }
    final relationshipChange = _changesRelationships(options);
    final storageKey = relationshipChange ? _relationshipsKey : _postsKey;
    Map<String, dynamic> snapshot() =>
        relationshipChange ? _relationshipSnapshot() : _postSnapshot();
    final persist =
        _preferences != null && (relationshipChange || _changesPosts(options));
    // Giữ bản độc lập để hoàn tác nếu ghi xuống máy thất bại.
    final previous = persist ? jsonEncode(snapshot()) : null;
    dynamic data;
    try {
      data = _route(options);
    } on _PreviewPostNotFound {
      return _response(
        null,
        status: 404,
        code: '1012',
        message: 'Bài viết không còn tồn tại.',
      );
    } on ApiException catch (e) {
      return _response(
        null,
        status: e.statusCode ?? 403,
        code: e.code ?? '1009',
        message: e.message,
      );
    }
    if (persist) {
      try {
        final saved = await _preferences.setString(
          storageKey,
          jsonEncode(snapshot()),
        );
        if (!saved) throw StateError('Could not save preview posts');
      } catch (_) {
        final old = jsonDecode(previous!) as Map<String, dynamic>;
        if (relationshipChange) {
          _applyRelationships(old);
        } else {
          _posts
            ..clear()
            ..addEntries([
              for (final row in old['posts'] as List)
                MapEntry(row['post_id'] as int, row as Map<String, dynamic>),
            ]);
          _nextId = old['next_id'] as int;
        }
        try {
          // SharedPreferences cập nhật cache trước khi ghi native: hoàn tác
          // cache nữa để mở lại backend không đọc nhầm lần lưu thất bại.
          await _preferences.setString(storageKey, previous);
        } catch (_) {
          // Vẫn báo lỗi lưu cho người dùng, không báo thành công giả.
        }
        return _response(
          null,
          status: 500,
          code: '1001',
          message: 'Không thể lưu thay đổi trên máy. Vui lòng thử lại.',
        );
      }
    }
    return _response(data);
  }

  Map<String, dynamic> _feedOf(Map<String, dynamic> post) => {
    'feed_id': post['post_id'],
    'target_type': 'POST',
    'target_id': post['post_id'],
    'action_type': 'CREATED_POST',
    'actor': post['author'],
    'content': post,
    'created_at': post['created_at'],
  };

  dynamic _route(RequestOptions o) {
    final path = o.path;
    final q = o.queryParameters;
    final m = o.method;
    final body = o.data is Map
        ? Map<String, dynamic>.from(o.data as Map)
        : <String, dynamic>{};

    Map<String, dynamic> page(List<dynamic> items) => {
      'items': items,
      'pagination': {'after': null, 'has_next': false},
    };

    final notifications = _notifications.route(m, path, q, body);
    if (!identical(notifications, PreviewNotifications.unhandled)) {
      return notifications;
    }

    final search = _search.route(m, path, q, body);
    if (!identical(search, PreviewSearch.unhandled)) return search;

    final qbank = _qbank.route(m, path, q, body);
    if (!identical(qbank, PreviewQbank.unhandled)) return qbank;

    if (path == '/auth/login' && m == 'POST') {
      // Chấp nhận mọi tài khoản trong bản xem trước (để thử luồng đăng nhập nhanh)
      return {
        'user_id': 1,
        'username': 'Nguyễn Văn An',
        'role': _role,
        'access_token': 'preview-access',
        'refresh_token': 'preview-refresh',
        'avatar_url': _me['avatar_url'],
        'profile_completed': true,
        'verified': true,
      };
    }
    if (path == '/users/me' && m == 'GET') {
      return {
        ..._me,
        'friends_count': _friendIds.length,
        'followers_count': _followers.length,
        'following_count': _following.length,
      };
    }
    if (path == '/users/me' && m == 'PUT') return {..._me, ...body};
    if (path.startsWith('/users/') && path.endsWith('/posts')) {
      final id = int.tryParse(path.split('/')[2]) ?? 0;
      _requireVisible(id);
      return page(
        _posts.values
            .where((p) => (p['author'] as Map)['user_id'] == id)
            .map(_visiblePost)
            .toList(),
      );
    }
    // ---- Cài đặt thông báo đẩy ----
    if (path == '/settings/push' && m == 'GET') {
      // Trả về bản sao để tránh nơi gọi vô tình sửa dữ liệu gốc.
      return jsonDecode(jsonEncode(_pushSettings));
    }

    if (path == '/settings/push' && m == 'PUT') {
      final currentCategories =
          _pushSettings['categories'] as Map<String, dynamic>;
      final currentQuietHours =
          _pushSettings['quiet_hours'] as Map<String, dynamic>;

      final categories = body['categories'] is Map
          ? Map<String, dynamic>.from(body['categories'] as Map)
          : currentCategories;

      final quietHours = body['quiet_hours'] is Map
          ? Map<String, dynamic>.from(body['quiet_hours'] as Map)
          : currentQuietHours;

      _pushSettings = {
        'push_enabled': body['push_enabled'] is bool
            ? body['push_enabled']
            : _pushSettings['push_enabled'],
        'categories': categories,
        'quiet_hours': quietHours,
        'sound_enabled': body['sound_enabled'] is bool
            ? body['sound_enabled']
            : _pushSettings['sound_enabled'],
        'vibration_enabled': body['vibration_enabled'] is bool
            ? body['vibration_enabled']
            : _pushSettings['vibration_enabled'],
      };

      return jsonDecode(jsonEncode(_pushSettings));
    }
    // ---- Bạn bè / tìm kiếm / theo dõi / chặn ----
    if (path == '/search' && m == 'GET') {
      final query = _fold((q['query'] ?? '').toString());
      final all = [
        for (var id = 2; id < 2 + _totalUsers; id++)
          if (!_blocked.contains(id)) _person(id),
      ];
      final matched = query.isEmpty
          ? all
          : all
                .where(
                  (u) =>
                      _fold(u['full_name'] as String).contains(query) ||
                      (u['student_lecturer_code'] as String).contains(query),
                )
                .toList();
      final from = int.tryParse('${q['after'] ?? 0}') ?? 0;
      final limit = int.tryParse('${q['limit'] ?? 20}') ?? 20;
      final slice = matched.skip(from).take(limit).toList();
      final next = from + slice.length;
      return {
        'items': [
          for (final u in slice)
            {'type': 'USER', 'relevance_score': 1.0, 'user': u},
        ],
        'pagination': {
          'before': null,
          'after': next < matched.length ? next : null,
          'has_prev': from > 0,
          'has_next': next < matched.length,
        },
        'total_hits': matched.length,
      };
    }
    if (path == '/friendships' && m == 'GET') {
      return {
        ...page([
          for (final id in _friendIds)
            {
              'user_id': id,
              'full_name': _person(id)['full_name'],
              'avatar_url': _person(id)['avatar_url'],
              'friends_since': '2026-09-20T00:00:00Z',
              'mutual_friends_count': id % 3,
            },
        ]),
        'total_friends': _friendIds.length,
      };
    }
    if (path == '/friendships/requests/received' && m == 'GET') {
      return {
        ...page([
          for (final id in _receivedFrom)
            {
              'requester': {
                'user_id': id,
                'full_name': _person(id)['full_name'],
                'avatar_url': _person(id)['avatar_url'],
              },
              'status': 'PENDING',
              'created_at': DateTime.now()
                  .toUtc()
                  .subtract(Duration(hours: id))
                  .toIso8601String(),
              'mutual_friends_count': id % 4,
            },
        ]),
        'total_pending': _receivedFrom.length,
      };
    }
    if (path == '/friendships/requests/sent' && m == 'GET') {
      return {
        ...page([
          for (final id in _sentTo)
            {
              'receiver': {
                'user_id': id,
                'full_name': _person(id)['full_name'],
                'avatar_url': _person(id)['avatar_url'],
              },
              'status': 'PENDING',
              'created_at': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
            },
        ]),
        'total_sent': _sentTo.length,
      };
    }
    if (path == '/friendships/request' && m == 'POST') {
      final id = int.tryParse('${body['addressee_id']}') ?? 0;
      _requireVisible(id);
      if (_receivedFrom.remove(id)) {
        _friendIds.add(id);
        return {'status': 'ACCEPTED'};
      }
      _sentTo.add(id);
      return {'status': 'PENDING'};
    }
    if (path == '/friendships/accept' && m == 'POST') {
      final id = int.tryParse('${body['requester_id']}') ?? 0;
      _requireVisible(id);
      if (_receivedFrom.remove(id)) _friendIds.add(id);
      return null;
    }
    if (path == '/friendships/decline' && m == 'POST') {
      _receivedFrom.remove(int.tryParse('${body['requester_id']}') ?? 0);
      return null;
    }
    if (path.startsWith('/friendships/') && m == 'DELETE') {
      _friendIds.remove(int.tryParse(path.split('/').last));
      return null;
    }
    if (path.startsWith('/follows/') &&
        !path.endsWith('ing') &&
        !path.endsWith('ers')) {
      final id = int.tryParse(path.split('/').last) ?? 0;
      if (m == 'POST') {
        _requireVisible(id);
        _following.add(id);
      }
      if (m == 'DELETE') _following.remove(id);
      return null;
    }
    if (path == '/follows/following' && m == 'GET') {
      return page([
        for (final id in _following)
          {
            'user_id': id,
            'full_name': _person(id)['full_name'],
            'avatar_url': _person(id)['avatar_url'],
            'avatar_frame_url': _person(id)['avatar_frame_url'],
          },
      ]);
    }
    if (path == '/follows/followers' && m == 'GET') {
      return page([
        for (final id in _followers)
          {
            'user_id': id,
            'full_name': _person(id)['full_name'],
            'avatar_url': _person(id)['avatar_url'],
            'avatar_frame_url': _person(id)['avatar_frame_url'],
          },
      ]);
    }
    if (path == '/blocks' && m == 'GET') {
      return {
        ...page([
          for (final id in _blocked)
            {
              'user_id': id,
              'full_name': _person(id)['full_name'],
              'avatar_url': _person(id)['avatar_url'],
              'avatar_frame_url': _person(id)['avatar_frame_url'],
            },
        ]),
        'total_blocked': _blocked.length,
      };
    }
    if (path.startsWith('/blocks/')) {
      final id = int.tryParse(path.split('/').last) ?? 0;
      if (m == 'POST') {
        if (id <= 1) {
          throw const ApiException(
            type: ApiErrorType.validation,
            statusCode: 400,
            message: 'Không thể chặn tài khoản này.',
          );
        }
        _blocked.add(id);
        _friendIds.remove(id);
        _sentTo.remove(id);
        _receivedFrom.remove(id);
        _following.remove(id);
        _followers.remove(id);
      }
      if (m == 'DELETE') _blocked.remove(id);
      return null;
    }
    if (path.startsWith('/users/') && m == 'GET') {
      final id = int.tryParse(path.split('/').last) ?? 2;
      _requireVisible(id);
      final u = _person(id);
      final pending = _sentTo.contains(id) || _receivedFrom.contains(id);
      return {
        'user_id': id,
        'full_name': u['full_name'],
        'avatar_url': u['avatar_url'],
        'cover_url': 'https://picsum.photos/seed/cover$id/1000/500',
        'bio': u['bio'],
        'student_lecturer_code': u['student_lecturer_code'],
        'school_faculty': u['school_faculty'],
        'major': u['major'],
        'role': u['role'],
        'friends_count': 45,
        'followers_count': 9,
        'following_count': 12,
        'gamification_points': 120,
        'badges_count': 1,
        'total_proposed_questions': 4,
        'relationships': {
          'is_friend': _friendIds.contains(id),
          'is_following': _following.contains(id),
          'is_followed': _followers.contains(id),
          'friend_request_status': _friendIds.contains(id)
              ? 'ACCEPTED'
              : (pending ? 'PENDING' : 'NONE'),
        },
      };
    }
    if (path == '/posts/me') {
      return page(
        _posts.values
            .where((p) => (p['author'] as Map)['user_id'] == 1)
            .map(_visiblePost)
            .toList(),
      );
    }
    if (path == '/activity-feeds') {
      final items = [
        for (final p in _posts.values.toList().reversed)
          if (!_blocked.contains((p['author'] as Map)['user_id']))
            _feedOf(_visiblePost(p)),
        if (!_blocked.contains(2))
          {
            'feed_id': 900,
            'target_type': 'BADGE',
            'target_id': 1,
            'action_type': 'EARNED_BADGE',
            'actor': _lan,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
      ];
      return page(items);
    }
    if (path == '/posts' && m == 'POST') {
      final id = _nextId++;
      final now = DateTime.now().toUtc().toIso8601String();
      _posts[id] = {
        'post_id': id,
        'content': body['content'] ?? '',
        'post_type': 'SOCIAL_POST',
        'visibility': body['visibility'] ?? 'PUBLIC',
        'media_urls': body['media_urls'] ?? [],
        'author': _me,
        'react_count': 0,
        'comment_count': 0,
        'reacted_by_me': false,
        'created_at': now,
        'updated_at': now,
      };
      return _posts[id];
    }
    if (path.startsWith('/posts/') && m == 'PUT') {
      final id = int.tryParse(path.split('/').last);
      final post = id == null ? null : _posts[id];
      if (post == null) throw const _PreviewPostNotFound();
      _requireVisible((post['author'] as Map)['user_id'] as int?);
      post.addAll({
        if (body.containsKey('content')) 'content': body['content'],
        if (body.containsKey('media_urls')) 'media_urls': body['media_urls'],
        if (body.containsKey('visibility')) 'visibility': body['visibility'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return post;
    }
    if (path.startsWith('/posts/') && m == 'GET') {
      final post = _posts[int.tryParse(path.split('/').last)];
      if (post == null) throw const _PreviewPostNotFound();
      _requireVisible((post['author'] as Map)['user_id'] as int?);
      return _visiblePost(post);
    }
    if (path.startsWith('/posts/') && m == 'DELETE') {
      final id = int.tryParse(path.split('/').last);
      final post = _posts[id];
      if (post == null) throw const _PreviewPostNotFound();
      _requireVisible((post['author'] as Map)['user_id'] as int?);
      _posts.remove(id);
      return null;
    }
    if (path == '/comments' && m == 'GET') {
      if (q['target_type'] == 'POST') {
        _requireVisible(
          (_posts[int.tryParse('${q['target_id']}')]?['author']
                  as Map?)?['user_id']
              as int?,
        );
      }
      if (q['parent_comment_id'] != null) {
        final parentId = int.tryParse('${q['parent_comment_id']}');
        if (parentId != _sampleCommentId(q, 1)) return page([]);
        if (_blocked.contains(3)) return page([]);
        return page([
          _visibleComment({
            'comment_id': _sampleCommentId(q, 2),
            ..._commentReactionFields(_sampleCommentId(q, 2)),
            'target_type': q['target_type'],
            'target_id': q['target_id'],
            'parent_comment_id': q['parent_comment_id'],
            'content': 'Chọn nút kế nhiệm thì thường ít xoay hơn bạn nhé.',
            'author': _me,
            'created_at': DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 5))
                .toIso8601String(),
          }),
        ]);
      }
      return page([
        _visibleComment({
          'comment_id': _sampleCommentId(q, 1),
          ..._commentReactionFields(_sampleCommentId(q, 1)),
          'target_type': q['target_type'],
          'target_id': q['target_id'],
          'content': 'Bạn thử vẽ cây ra giấy rồi so sánh từng bước xem.',
          'author': _minh,
          'reply_count': 1,
          'created_at': DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 12))
              .toIso8601String(),
        }),
        _visibleComment({
          'comment_id': _sampleCommentId(q, 3),
          ..._commentReactionFields(_sampleCommentId(q, 3)),
          'target_type': q['target_type'],
          'target_id': q['target_id'],
          'content': 'Mình cũng đang thắc mắc đúng chỗ này 😅',
          'author': _lan,
          'created_at': DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 40))
              .toIso8601String(),
        }),
      ]);
    }
    if (path == '/comments' && m == 'POST') {
      if (body['target_type'] == 'POST') {
        _requireVisible(
          (_posts[int.tryParse('${body['target_id']}')]?['author']
                  as Map?)?['user_id']
              as int?,
        );
      }
      final parent = int.tryParse('${body['parent_comment_id']}');
      if (parent != null) _requireCommentVisible(parent);
      return _visibleComment({
        'comment_id': _nextCommentId++,
        'react_count': 0,
        'reacted_by_me': false,
        'target_type': body['target_type'],
        'target_id': body['target_id'],
        'parent_comment_id': body['parent_comment_id'],
        'content': body['content'],
        'author': _me,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    if (path == '/react') {
      if (body['target_type'] == 'POST') {
        _requireVisible(
          (_posts[int.tryParse('${body['target_id']}')]?['author']
                  as Map?)?['user_id']
              as int?,
        );
      }
      final key = '${body['target_type']}-${body['target_id']}';
      final liked = !(_liked[key] ?? false);
      _liked[key] = liked;
      return {
        'my_reaction': liked ? 'LIKE' : 'NONE',
        'total_count': liked ? 13 : 12,
      };
    }
    if (path == '/medias/upload') {
      final id = _nextId++;
      return {
        'object_key': 'preview/$id.jpg',
        'url': 'https://picsum.photos/seed/up$id/900/700',
        'file_size': 120000,
        'content_type': 'image/jpeg',
        'media_type': 'IMAGE',
        'width': 900,
        'height': 700,
      };
    }
    return null;
  }

  /// Chữ thường + bỏ dấu tiếng Việt (để tìm "tung" ra "Tùng").
  static String _fold(String input) {
    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final buf = StringBuffer();
    for (final ch in input.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString().trim();
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Giả lập độ trễ mạng nhẹ
    await Future<void>.delayed(const Duration(milliseconds: 350));
    // Tuần tự cả đọc/ghi để request sau không thấy dữ liệu chưa ghi thành công.
    final before = _pendingRequest;
    final done = Completer<void>();
    _pendingRequest = done.future;
    await before;
    try {
      return await _respond(options);
    } finally {
      done.complete();
    }
  }

  @override
  void close({bool force = false}) {}
}

class _PreviewPostNotFound implements Exception {
  const _PreviewPostNotFound();
}
