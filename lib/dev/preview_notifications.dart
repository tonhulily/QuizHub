/// Dữ liệu mẫu cho API thông báo trong bản xem trước.
///
/// Hỗ trợ:
/// - GET  /notifications?after=offset&limit=size
/// - POST /notifications/{id}/read
/// - POST /notifications/read-all
///
/// Trạng thái chỉ lưu trong RAM và được reset khi khởi động lại preview.
class PreviewNotifications {
  static const Object unhandled = Object();

  final List<Map<String, dynamic>> _items = [];

  PreviewNotifications() {
    final now = DateTime.now().toUtc();

    String ago(Duration duration) =>
        now.subtract(duration).toIso8601String();

    final samples = <Map<String, dynamic>>[
      // ============================================================
      // FRIEND REQUEST
      // ============================================================
      {
        'type': 'FRIEND_REQUEST',
        'title': 'đã gửi cho bạn lời mời kết bạn.',
        'body': 'Hãy kết nối để cùng trao đổi và học tập nhé!',
        'actor': _actor(2, 'Trần Thị Lan', 47),
        'target': {'type': 'USER', 'target_id': 2},
        'metadata': <String, dynamic>{},
      },

      // ============================================================
      // FRIEND ACCEPTED
      // ============================================================
      {
        'type': 'FRIEND_ACCEPTED',
        'title': 'đã chấp nhận lời mời kết bạn của bạn.',
        'body': '',
        'actor': _actor(5, 'Nguyễn Hoàng Long', 15),
        'target': {'type': 'USER', 'target_id': 5},
        'metadata': <String, dynamic>{},
      },

      // ============================================================
      // POST REACTION
      // ============================================================
      {
        'type': 'POST_REACTION',
        'title': 'đã thích bài viết của bạn.',
        'body': 'Ảnh sơ đồ cây bạn chia sẻ khi ôn tập.',
        'actor': _actor(3, 'Lê Quang Minh', 33),
        'target': {'type': 'POST', 'target_id': 12},
        'metadata': {'reaction': 'LIKE'},
      },
      {
        'type': 'POST_REACTION',
        'title': 'đã bày tỏ cảm xúc về bài viết của bạn.',
        'body': 'Thư viện Tạ Quang Bửu mùa thi 🌿',
        'actor': _actor(6, 'Đỗ Khánh Linh', 44),
        'target': {'type': 'POST', 'target_id': 13},
        'metadata': {'reaction': 'LOVE'},
      },

      // ============================================================
      // NEW COMMENT
      // ============================================================
      // Target POST và target_id là ID bài viết:
      // Đây là giả định cần xác minh thêm với backend.
      {
        'type': 'NEW_COMMENT',
        'title': 'đã bình luận về bài viết của bạn.',
        'body': 'Sơ đồ này rất hữu ích, cảm ơn bạn đã chia sẻ!',
        'actor': _actor(4, 'Phạm Đức Anh', 12),
        'target': {'type': 'POST', 'target_id': 12},
        'metadata': {
          'comment_id': 301,
        },
      },

      // ============================================================
      // COMMENT REPLY
      // ============================================================
      {
        'type': 'COMMENT_REPLY',
        'title': 'đã trả lời bình luận của bạn.',
        'body': 'Mình cũng thường chọn cách này khi cài đặt AVL.',
        'actor': _actor(7, 'Hoàng Gia Bảo', 21),
        'target': {'type': 'POST', 'target_id': 11},
        'metadata': {
          'comment_id': 202,
          'parent_comment_id': 201,
        },
      },

      // ============================================================
      // QUESTION APPROVED
      // ============================================================
      // Target SESSION: ID phiên đề xuất câu hỏi.
      {
        'type': 'QUESTION_APPROVED',
        'title': 'Câu hỏi bạn đề xuất đã được duyệt.',
        'body': 'Môn Cấu trúc dữ liệu và giải thuật · IT3011',
        'icon_url':
            'https://cdn-icons-png.flaticon.com/512/190/190411.png',
        'target': {'type': 'SESSION', 'target_id': 501},
        'metadata': {
          'session_id': 501,
          'question_id': 101,
          'subject_code': 'IT3011',
        },
      },

      // ============================================================
      // EARNED BADGE
      // ============================================================
      // Target BADGE: ID huy hiệu được trao.
      {
        'type': 'EARNED_BADGE',
        'title': 'Bạn đã nhận được một huy hiệu mới!',
        'body': 'Huy hiệu Người đóng góp tích cực.',
        'icon_url':
            'https://cdn-icons-png.flaticon.com/512/2583/2583344.png',
        'target': {'type': 'BADGE', 'target_id': 7},
        'metadata': {
          'badge_id': 7,
        },
      },

      // ============================================================
      // QUESTION ERROR PENALTY
      // ============================================================
      {
        'type': 'QUESTION_ERROR_PENALTY',
        'title': 'Một câu hỏi của bạn đã bị xác nhận có lỗi.',
        'body': 'Câu hỏi cần được kiểm tra và chỉnh sửa lại.',
        'icon_url':
            'https://cdn-icons-png.flaticon.com/512/1828/1828843.png',
        'target': {'type': 'QUESTION', 'target_id': 102},
        'metadata': {
          'question_id': 102,
          'subject_code': 'IT3011',
        },
      },

      // ============================================================
      // GAME5 SEMESTER RECAP
      // ============================================================
      {
        'type': 'GAME5_SEMESTER_RECAP',
        'title': 'Tổng kết Game5 học kỳ đã sẵn sàng!',
        'body': 'Cùng xem lại thành tích và những dấu ấn của bạn.',
        'icon_url':
            'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
        'target': {'type': 'USER', 'target_id': 1},
        'metadata': {
          'user_id': 1,
        },
      },

      // ============================================================
      // LEADERBOARD HONOR
      // ============================================================
      {
        'type': 'LEADERBOARD_HONOR',
        'title': 'Bạn được vinh danh trên bảng xếp hạng!',
        'body': 'Thành tích học tập của bạn đã được ghi nhận.',
        'icon_url':
            'https://cdn-icons-png.flaticon.com/512/3112/3112946.png',
        'target': {'type': 'POST', 'target_id': 15},
        'metadata': {
          'post_id': 15,
        },
      },

      // ============================================================
      // SYSTEM
      // ============================================================
      {
        'type': 'SYSTEM',
        'title': 'Chào mừng bạn đến với QuizHub!',
        'body':
            'Khám phá ngân hàng câu hỏi, chia sẻ kiến thức và kết nối với bạn bè.',
        'icon_url': null,
        'target': {'type': 'HOME'},
        'metadata': {
          'category': 'WELCOME',
        },
      },
    ];

    // Tạo 33 bản ghi để kiểm tra:
    // - Tất cả loại thông báo.
    // - Phân trang.
    // - Trạng thái đã đọc/chưa đọc.
    // - Điều hướng lặp lại nhiều lần.
    for (var i = 0; i < 33; i++) {
      final sample = samples[i % samples.length];

      final createdAt = ago(
        Duration(
          minutes: i < 4 ? (i + 1) * 7 : 60 * (i - 2),
        ),
      );

      _items.add({
        'notification_id': 2000 + i,
        'type': sample['type'],
        'title': sample['title'],
        'body': sample['body'],
        'icon_url': sample['icon_url'],
        'read_at': i % 5 == 3 || i > 22
            ? ago(Duration(hours: i + 1))
            : null,
        'created_at': createdAt,
        'target': sample['target'],
        'actor': sample['actor'],
        'metadata': sample['metadata'],
      });
    }
  }

  // ==============================================================
  // ACTOR
  // ==============================================================

  static Map<String, dynamic> _actor(
    int id,
    String name,
    int avatar,
  ) =>
      {
        'user_id': id,
        'full_name': name,
        'avatar_url': 'https://i.pravatar.cc/150?img=$avatar',
        'frame_url': null,
      };

  // ==============================================================
  // UNREAD COUNT
  // ==============================================================

  int get _unreadCount =>
      _items.where((item) => item['read_at'] == null).length;

  // ==============================================================
  // API ROUTER
  // ==============================================================

  dynamic route(
    String method,
    String path,
    Map<String, dynamic> query,
    Map<dynamic, dynamic> body,
  ) {
    final m = method.toUpperCase();

    // ------------------------------------------------------------
    // GET /notifications
    // ------------------------------------------------------------

    if (path == '/notifications' && m == 'GET') {
      final offset = (int.tryParse('${query['after'] ?? 0}') ?? 0)
          .clamp(0, _items.length)
          .toInt();

      final limit = (int.tryParse('${query['limit'] ?? 20}') ?? 20)
          .clamp(1, 50)
          .toInt();

      final end = (offset + limit)
          .clamp(0, _items.length)
          .toInt();

      final items = _items.sublist(offset, end);
      final hasNext = end < _items.length;

      return {
        'items': items,
        'pagination': {
          'before': offset > 0
              ? (offset - limit).clamp(0, _items.length).toInt()
              : null,
          'after': hasNext ? end : null,
          'has_prev': offset > 0,
          'has_next': hasNext,
        },
        'unread_count': _unreadCount,
      };
    }

    // ------------------------------------------------------------
    // POST /notifications/read-all
    // ------------------------------------------------------------

    if (path == '/notifications/read-all' && m == 'POST') {
      final readAt = DateTime.now().toUtc().toIso8601String();

      for (final item in _items) {
        item['read_at'] ??= readAt;
      }

      return <String, dynamic>{};
    }

    // ------------------------------------------------------------
    // POST /notifications/{id}/read
    // ------------------------------------------------------------

    final readMatch =
        RegExp(r'^/notifications/(\d+)/read$').firstMatch(path);

    if (readMatch != null && m == 'POST') {
      final id = int.parse(readMatch.group(1)!);

      final index = _items.indexWhere(
        (item) => item['notification_id'] == id,
      );

      if (index < 0) {
        return <String, dynamic>{
          'notification_id': id,
          'read_at': null,
          'unread_count': _unreadCount,
          'read': false,
        };
      }

      final item = _items[index];

      item['read_at'] ??= DateTime.now().toUtc().toIso8601String();

      return {
        'notification_id': id,
        'read_at': item['read_at'],
        'unread_count': _unreadCount,
        'read': true,
      };
    }

    return unhandled;
  }
}
