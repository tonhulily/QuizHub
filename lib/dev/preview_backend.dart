import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/storage/token_storage.dart';

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
/// Chỉ phục vụ giao diện: dữ liệu nằm trong RAM, mất khi thoát app.
class PreviewBackend implements HttpClientAdapter {
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
    'role': 'STUDENT',
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

  final Map<int, Map<String, dynamic>> _posts = {};
  final Map<String, bool> _liked = {};
  int _nextId = 100;

  PreviewBackend() {
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
    final body = o.data is Map ? Map<String, dynamic>.from(o.data as Map) : {};

    Map<String, dynamic> page(List<dynamic> items) => {
      'items': items,
      'pagination': {'after': null, 'has_next': false},
    };

    if (path == '/auth/login' && m == 'POST') {
      // Chấp nhận mọi tài khoản trong bản xem trước (để thử luồng đăng nhập nhanh)
      return {
        'user_id': 1,
        'username': 'Nguyễn Văn An',
        'role': 'STUDENT',
        'access_token': 'preview-access',
        'refresh_token': 'preview-refresh',
        'avatar_url': _me['avatar_url'],
        'profile_completed': true,
        'verified': true,
      };
    }
    if (path == '/users/me' && m == 'GET') return _me;
    if (path == '/users/me' && m == 'PUT') return {..._me, ...body};
    if (path.startsWith('/users/') && path.endsWith('/posts')) {
      final id = int.tryParse(path.split('/')[2]) ?? 0;
      return page(
        _posts.values
            .where((p) => (p['author'] as Map)['user_id'] == id)
            .toList(),
      );
    }
    // ---- Bạn bè / tìm kiếm / theo dõi / chặn (dữ liệu mẫu trong RAM) ----
    if (path == '/search' && m == 'GET') {
      final query = _fold((q['query'] ?? '').toString());
      final all = [for (var id = 2; id < 2 + _totalUsers; id++) _person(id)];
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
      if (_receivedFrom.remove(id)) {
        _friendIds.add(id);
        return {'status': 'ACCEPTED'};
      }
      _sentTo.add(id);
      return {'status': 'PENDING'};
    }
    if (path == '/friendships/accept' && m == 'POST') {
      final id = int.tryParse('${body['requester_id']}') ?? 0;
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
      if (m == 'POST') _following.add(id);
      if (m == 'DELETE') _following.remove(id);
      return null;
    }
    if (path == '/blocks' && m == 'GET') {
      return {
        ...page([
          for (final id in _blocked)
            {'user_id': id, 'full_name': _person(id)['full_name']},
        ]),
        'total_blocked': _blocked.length,
      };
    }
    if (path.startsWith('/blocks/')) {
      final id = int.tryParse(path.split('/').last) ?? 0;
      if (m == 'POST') {
        _blocked.add(id);
        _friendIds.remove(id);
        _sentTo.remove(id);
        _receivedFrom.remove(id);
        _following.remove(id);
      }
      if (m == 'DELETE') _blocked.remove(id);
      return null;
    }
    if (path.startsWith('/users/') && m == 'GET') {
      final id = int.tryParse(path.split('/').last) ?? 2;
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
          'is_followed': false,
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
            .toList(),
      );
    }
    if (path == '/activity-feeds') {
      final items = [
        for (final p in _posts.values.toList().reversed) _feedOf(p),
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
      if (post == null) return null;
      post.addAll({
        if (body.containsKey('content')) 'content': body['content'],
        if (body.containsKey('media_urls')) 'media_urls': body['media_urls'],
        if (body.containsKey('visibility')) 'visibility': body['visibility'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return post;
    }
    if (path.startsWith('/posts/') && m == 'GET') {
      return _posts[int.tryParse(path.split('/').last)];
    }
    if (path.startsWith('/posts/') && m == 'DELETE') {
      _posts.remove(int.tryParse(path.split('/').last));
      return null;
    }
    if (path == '/comments' && m == 'GET') {
      if (q['parent_comment_id'] != null) {
        return page([
          {
            'comment_id': 202,
            'target_type': 'POST',
            'target_id': q['target_id'],
            'parent_comment_id': q['parent_comment_id'],
            'content': 'Chọn nút kế nhiệm thì thường ít xoay hơn bạn nhé.',
            'author': _me,
            'created_at': DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 5))
                .toIso8601String(),
          },
        ]);
      }
      return page([
        {
          'comment_id': 201,
          'target_type': 'POST',
          'target_id': q['target_id'],
          'content': 'Bạn thử vẽ cây ra giấy rồi so sánh từng bước xem.',
          'author': _minh,
          'reply_count': 1,
          'created_at': DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 12))
              .toIso8601String(),
        },
        {
          'comment_id': 203,
          'target_type': 'POST',
          'target_id': q['target_id'],
          'content': 'Mình cũng đang thắc mắc đúng chỗ này 😅',
          'author': _lan,
          'created_at': DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 40))
              .toIso8601String(),
        },
      ]);
    }
    if (path == '/comments' && m == 'POST') {
      return {
        'comment_id': _nextId++,
        'target_type': body['target_type'],
        'target_id': body['target_id'],
        'parent_comment_id': body['parent_comment_id'],
        'content': body['content'],
        'author': _me,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
    if (path == '/react') {
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
    final data = _route(options);
    return ResponseBody.fromString(
      jsonEncode({'code': '0000', 'message': 'OK', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
