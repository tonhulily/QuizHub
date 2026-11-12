import '../core/utils/json_utils.dart';

/// Dữ liệu mẫu cho Global Search trong bản xem trước.
///
/// Hỗ trợ:
/// - GET    /search
/// - GET    /search/saved
/// - POST   /search/saved
/// - DELETE /search/saved/{id}
///
/// Dữ liệu chỉ tồn tại trong RAM, không gọi backend thật.
class PreviewSearch {
  static const Object unhandled = Object();

  static const List<String> _trendingSearches = [
    'Cấu trúc dữ liệu',
    'Hệ điều hành',
    'Thuật toán sắp xếp',
    'Lập trình hướng đối tượng',
    'Cơ sở dữ liệu',
  ];

  final List<Map<String, dynamic>> _savedSearches = [];
  int _nextSavedSearchId = 1;

  late final List<Map<String, dynamic>> _documents = _buildDocuments();

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static String _ago(int days) =>
      DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();

  // ------------------------------------------------------------------
  // Dữ liệu mẫu
  // ------------------------------------------------------------------

  List<Map<String, dynamic>> _buildDocuments() {
    final users = <Map<String, dynamic>>[
      {
        'user_id': 2,
        'full_name': 'Nguyễn Minh Anh',
        'student_lecturer_code': '20220001',
        'email': 'minhanh@example.com',
        'bio': 'Sinh viên Công nghệ thông tin, yêu thích thuật toán.',
        'avatar_url': null,
        'avatar_frame_url': null,
        'school_faculty': 'Trường Công nghệ thông tin và Truyền thông',
        'major': 'Khoa học máy tính',
        'role': 'STUDENT',
        'total_proposed_questions': 12,
        'badges_count': 3,
        'followers_count': 128,
      },
      {
        'user_id': 3,
        'full_name': 'Lê Quang Minh',
        'student_lecturer_code': 'GV001',
        'email': 'minh.lq@example.com',
        'bio': 'Giảng viên, quan tâm đến hệ điều hành và hệ thống phân tán.',
        'avatar_url': null,
        'avatar_frame_url': null,
        'school_faculty': 'Trường Công nghệ thông tin và Truyền thông',
        'major': 'Khoa học máy tính',
        'role': 'LECTURER',
        'total_proposed_questions': 35,
        'badges_count': 5,
        'followers_count': 256,
      },
      {
        'user_id': 4,
        'full_name': 'Trần Thu Hà',
        'student_lecturer_code': '20220004',
        'email': 'thuha@example.com',
        'bio': 'Chia sẻ tài liệu và câu hỏi ôn tập.',
        'avatar_url': null,
        'avatar_frame_url': null,
        'school_faculty': 'Trường Công nghệ thông tin và Truyền thông',
        'major': 'Kỹ thuật phần mềm',
        'role': 'STUDENT',
        'total_proposed_questions': 8,
        'badges_count': 2,
        'followers_count': 96,
      },
    ];

    final subjects = <Map<String, dynamic>>[
      {
        'subject_id': 10,
        'code': 'IT3011',
        'name': 'Cấu trúc dữ liệu và thuật toán',
      },
      {'subject_id': 11, 'code': 'IT3070', 'name': 'Nguyên lý hệ điều hành'},
      {
        'subject_id': 12,
        'code': 'IT3180',
        'name': 'Nhập môn công nghệ phần mềm',
      },
    ];

    final posts = <Map<String, dynamic>>[
      {
        'post_id': 1001,
        'content':
            'Mình vừa tổng hợp một số bài tập về cây AVL và cây nhị phân tìm kiếm. '
            'Mọi người cùng tham khảo nhé!',
        'author_id': 2,
        'author_name': 'Nguyễn Minh Anh',
        'author_avatar_url': null,
        'author_frame_url': null,
        'post_type': 'TEXT',
        'media_urls': <String>[],
        'react_count': 18,
        'comment_count': 5,
        'created_at': _ago(1),
      },
      {
        'post_id': 1002,
        'content':
            'Chia sẻ tài liệu ôn tập môn Nguyên lý hệ điều hành: tiến trình, '
            'định thời CPU và quản lý bộ nhớ.',
        'author_id': 3,
        'author_name': 'Lê Quang Minh',
        'author_avatar_url': null,
        'author_frame_url': null,
        'post_type': 'TEXT',
        'media_urls': <String>[],
        'react_count': 32,
        'comment_count': 9,
        'created_at': _ago(3),
      },
      {
        'post_id': 1003,
        'content':
            'Có ai có kinh nghiệm giải bài tập về thuật toán sắp xếp nhanh '
            '(Quick Sort) không? Cùng trao đổi nhé.',
        'author_id': 4,
        'author_name': 'Trần Thu Hà',
        'author_avatar_url': null,
        'author_frame_url': null,
        'post_type': 'TEXT',
        'media_urls': <String>[],
        'react_count': 7,
        'comment_count': 3,
        'created_at': _ago(5),
      },
    ];

    final questions = <Map<String, dynamic>>[
      {
        'question_id': 101,
        'question_code': 'IT3011-Q101',
        'subject_id': 10,
        'subject_name': 'Cấu trúc dữ liệu và thuật toán',
        'topic_id': 1,
        'topic_name': 'Cây cân bằng',
        'status': 'APPROVED',
        'difficulty': 'EASY',
        'content':
            'Độ phức tạp thời gian của thao tác tìm kiếm trên cây AVL có n nút là?',
        'options': [
          {'key': 'A', 'text': 'O(1)'},
          {'key': 'B', 'text': 'O(log n)'},
          {'key': 'C', 'text': 'O(n)'},
          {'key': 'D', 'text': 'O(n log n)'},
        ],
        'explanation':
            'Cây AVL luôn được cân bằng nên chiều cao cây là O(log n).',
        'image_urls': <String>[],
        'avg_rating': 4.5,
        'rating_count': 12,
        'react_count': 20,
        'comment_count': 4,
        'created_at': _ago(10),
      },
      {
        'question_id': 201,
        'question_code': 'IT3070-Q201',
        'subject_id': 11,
        'subject_name': 'Nguyên lý hệ điều hành',
        'topic_id': 2,
        'topic_name': 'Định thời CPU',
        'status': 'APPROVED',
        'difficulty': 'MEDIUM',
        'content':
            'Thuật toán định thời nào có thể gây đói (starvation) cho tiến trình dài?',
        'options': [
          {'key': 'A', 'text': 'Round Robin'},
          {'key': 'B', 'text': 'Shortest Job First'},
          {'key': 'C', 'text': 'First Come First Served'},
          {'key': 'D', 'text': 'Không thuật toán nào'},
        ],
        'explanation':
            'SJF có thể khiến tiến trình dài phải chờ nếu liên tục xuất hiện '
            'các tiến trình ngắn hơn.',
        'image_urls': <String>[],
        'avg_rating': 4.2,
        'rating_count': 8,
        'react_count': 14,
        'comment_count': 2,
        'created_at': _ago(7),
      },
      {
        'question_id': 301,
        'question_code': 'IT3180-Q301',
        'subject_id': 12,
        'subject_name': 'Nhập môn công nghệ phần mềm',
        'topic_id': 3,
        'topic_name': 'Kiểm thử phần mềm',
        'status': 'APPROVED',
        'difficulty': 'HARD',
        'content':
            'Mục tiêu chính của kiểm thử hồi quy (Regression Testing) là gì?',
        'options': [
          {
            'key': 'A',
            'text': 'Kiểm tra các chức năng cũ sau khi thay đổi phần mềm',
          },
          {'key': 'B', 'text': 'Đo tốc độ mạng'},
          {'key': 'C', 'text': 'Thiết kế giao diện'},
          {'key': 'D', 'text': 'Nén mã nguồn'},
        ],
        'explanation':
            'Kiểm thử hồi quy nhằm phát hiện lỗi phát sinh ở chức năng đã có '
            'sau khi phần mềm được thay đổi.',
        'image_urls': <String>[],
        'avg_rating': 4.8,
        'rating_count': 6,
        'react_count': 11,
        'comment_count': 1,
        'created_at': _ago(2),
      },
    ];

    final sessions = <Map<String, dynamic>>[
      {
        'session_id': 1,
        'title': 'Ôn tập cây cân bằng AVL',
        'content': 'Bộ câu hỏi ôn tập về cây AVL và cây nhị phân tìm kiếm.',
        'subject_id': 10,
        'subject_name': 'Cấu trúc dữ liệu và thuật toán',
        'status': 'RESOLVED',
        'question_count': 8,
        'react_count': 15,
        'comment_count': 3,
        'created_at': _ago(20),
      },
      {
        'session_id': 2,
        'title': 'Định thời CPU - chương 5',
        'content': 'Các câu hỏi về FCFS, SJF, Round Robin và Priority.',
        'subject_id': 11,
        'subject_name': 'Nguyên lý hệ điều hành',
        'status': 'RESOLVED',
        'question_count': 12,
        'react_count': 21,
        'comment_count': 6,
        'created_at': _ago(12),
      },
      {
        'session_id': 3,
        'title': 'Kiểm thử phần mềm',
        'content':
            'Ôn tập kiểm thử đơn vị, kiểm thử tích hợp và kiểm thử hồi quy.',
        'subject_id': 12,
        'subject_name': 'Nhập môn công nghệ phần mềm',
        'status': 'RESOLVED',
        'question_count': 10,
        'react_count': 9,
        'comment_count': 2,
        'created_at': _ago(4),
      },
    ];

    return [
      for (final p in posts)
        {
          'type': 'POST',
          'relevance_score': 1.0,
          'post': p,
          // Một kết quả có thể chứa nhiều entity cùng lúc.
          'user': users.firstWhere((u) => u['user_id'] == p['author_id']),
          '_search_text': '${p['content']} ${p['author_name']}',
        },
      for (final u in users)
        {
          'type': 'USER',
          'relevance_score': 1.0,
          'user': u,
          '_search_text':
              '${u['full_name']} ${u['student_lecturer_code']} '
              '${u['email']} ${u['bio']} ${u['major']}',
        },
      for (final q in questions)
        {
          'type': 'QUESTION',
          'relevance_score': 1.0,
          'question': q,
          '_search_text':
              '${q['content']} ${q['question_code']} '
              '${q['subject_name']} ${q['topic_name']}',
        },
      for (final s in sessions)
        {
          'type': 'SESSION',
          'relevance_score': 1.0,
          'session': s,
          '_search_text': '${s['title']} ${s['content']} ${s['subject_name']}',
        },
      for (final s in subjects)
        {
          'type': 'SUBJECT',
          'relevance_score': 1.0,
          'subject': s,
          '_search_text': '${s['code']} ${s['name']}',
        },
    ];
  }

  // ------------------------------------------------------------------
  // Tìm kiếm
  // ------------------------------------------------------------------

  Map<String, dynamic> _search(Map<String, dynamic> query) {
    final keyword = J.stringOr(query['query']).trim().toLowerCase();
    final type = J.stringOr(query['type'], 'ALL').toUpperCase();

    final offset = (J.asInt(query['after']) ?? 0).clamp(0, 1 << 30);
    final limit = (J.asInt(query['limit']) ?? 20).clamp(1, 50);

    const supportedTypes = {
      'ALL',
      'POST',
      'USER',
      'QUESTION',
      'SESSION',
      'SUBJECT',
    };

    if (!supportedTypes.contains(type)) {
      return _emptyPage();
    }

    // Không trả kết quả nếu người dùng chưa nhập từ khóa.
    if (keyword.isEmpty) {
      return _emptyPage();
    }

    final matched = _documents.where((item) {
      final matchesType = type == 'ALL' || item['type'] == type;
      final text = J.stringOr(item['_search_text']).toLowerCase();
      return matchesType && text.contains(keyword);
    }).toList();

    final total = matched.length;
    final start = offset.clamp(0, total);
    final end = (start + limit).clamp(0, total);
    final pageItems = matched.sublist(start, end);

    final hasPrev = start > 0;
    final hasNext = end < total;

    return {
      'items': [
        for (final item in pageItems)
          {
            for (final entry in item.entries)
              if (!entry.key.startsWith('_')) entry.key: entry.value,
          },
      ],
      'pagination': {
        'before': hasPrev ? (start - limit).clamp(0, total) : null,
        'after': hasNext ? end : null,
        'has_prev': hasPrev,
        'has_next': hasNext,
      },
      'total_hits': total,
    };
  }

  Map<String, dynamic> _emptyPage() => {
    'items': <Map<String, dynamic>>[],
    'pagination': {
      'before': null,
      'after': null,
      'has_prev': false,
      'has_next': false,
    },
    'total_hits': 0,
  };

  // ------------------------------------------------------------------
  // Lịch sử tìm kiếm
  // ------------------------------------------------------------------

  Map<String, dynamic> _getSavedSearches() => {
    'saved_searches': [
      for (final item in _savedSearches) Map<String, dynamic>.from(item),
    ],
    'trending_searches': _trendingSearches,
  };

  void _saveSearch(Map<dynamic, dynamic> body) {
    final keyword = J.stringOr(body['query']).trim();
    if (keyword.isEmpty) return;

    // Nếu từ khóa đã có, đưa nó lên đầu danh sách và cập nhật thời gian.
    _savedSearches.removeWhere(
      (item) =>
          J.stringOr(item['query_text']).toLowerCase() == keyword.toLowerCase(),
    );

    _savedSearches.insert(0, {
      'saved_search_id': _nextSavedSearchId++,
      'query_text': keyword,
      'last_searched_at': _now(),
    });

    // Giới hạn 20 từ khóa gần nhất.
    if (_savedSearches.length > 20) {
      _savedSearches.removeRange(20, _savedSearches.length);
    }
  }

  void _deleteSavedSearch(String path) {
    final id = int.tryParse(path.split('/').last);
    if (id == null) return;

    _savedSearches.removeWhere((item) => item['saved_search_id'] == id);
  }

  // ------------------------------------------------------------------
  // Định tuyến
  // ------------------------------------------------------------------

  dynamic route(
    String method,
    String path,
    Map<String, dynamic> query,
    Map<dynamic, dynamic> body,
  ) {
    final m = method.toUpperCase();

    if (path == '/search' && m == 'GET') {
      return _search(query);
    }

    if (path == '/search/saved' && m == 'GET') {
      return _getSavedSearches();
    }

    if (path == '/search/saved' && m == 'POST') {
      _saveSearch(body);
      return null;
    }

    if (path.startsWith('/search/saved/') && m == 'DELETE') {
      _deleteSavedSearch(path);
      return null;
    }

    return unhandled;
  }
}
