import '../core/utils/json_utils.dart';

/// Nguồn dữ liệu và response thống nhất cho Global Search trong preview.
///
/// Mọi GET /search đi qua lớp này. Dữ liệu được đọc trực tiếp từ các module
/// sở hữu chúng để kết quả phản ánh trạng thái hiện tại của preview.
class PreviewSearch {
  static const Object unhandled = Object();

  final List<Map<String, dynamic>> Function() users;
  final List<Map<String, dynamic>> Function() posts;
  final List<Map<String, dynamic>> Function() questions;
  final List<Map<String, dynamic>> Function() sessions;
  final List<Map<String, dynamic>> Function() subjects;
  final bool Function(int userId) isBlocked;

  PreviewSearch({
    required this.users,
    required this.posts,
    required this.questions,
    required this.sessions,
    required this.subjects,
    bool Function(int userId)? isBlocked,
  }) : isBlocked = isBlocked ?? _neverBlocked;

  static bool _neverBlocked(int userId) => false;

  static const List<String> _trendingSearches = [
    'Cấu trúc dữ liệu',
    'Hệ điều hành',
    'Thuật toán sắp xếp',
    'Lập trình hướng đối tượng',
    'Cơ sở dữ liệu',
  ];

  final List<Map<String, dynamic>> _savedSearches = [];
  int _nextSavedSearchId = 1;

  static String _now() => DateTime.now().toUtc().toIso8601String();

  /// Chữ thường + bỏ dấu tiếng Việt (để "tung" tìm được "Tùng").
  static String _fold(String input) {
    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final buffer = StringBuffer();
    for (final character in input.toLowerCase().split('')) {
      final index = from.indexOf(character);
      buffer.write(index >= 0 ? to[index] : character);
    }
    return buffer.toString().trim();
  }

  int? _authorId(Map<String, dynamic> post) {
    final author = post['author'];
    if (author is Map) {
      final id = author['user_id'];
      if (id is int) return id;
    }
    final id = post['author_id'];
    return id is int ? id : null;
  }

  String _postText(Map<String, dynamic> post) {
    final author = post['author'];
    final authorName = author is Map
        ? J.stringOr(author['full_name'])
        : J.stringOr(post['author_name']);
    return '${post['content'] ?? ''} $authorName '
        '${post['subject_name'] ?? ''} ${post['subject_code'] ?? ''}';
  }

  List<Map<String, dynamic>> _documents() {
    final result = <Map<String, dynamic>>[];

    for (final user in users()) {
      final id = user['user_id'];
      if (id is int && isBlocked(id)) continue;
      result.add({
        'type': 'USER',
        'relevance_score': 1.0,
        'user': user,
        '_search_text': [
          user['full_name'],
          user['student_lecturer_code'],
          user['email'],
          user['bio'],
          user['major'],
        ].whereType<Object>().join(' '),
      });
    }

    for (final post in posts()) {
      final authorId = _authorId(post);
      if (authorId != null && isBlocked(authorId)) continue;
      final author = post['author'];
      result.add({
        'type': 'POST',
        'relevance_score': 1.0,
        'post': post,
        if (author is Map) 'user': author,
        '_search_text': _postText(post),
      });
    }

    for (final question in questions()) {
      result.add({
        'type': 'QUESTION',
        'relevance_score': 1.0,
        'question': question,
        '_search_text': [
          question['content'],
          question['question_code'],
          question['subject_name'],
          question['topic_name'],
        ].whereType<Object>().join(' '),
      });
    }

    for (final session in sessions()) {
      result.add({
        'type': 'SESSION',
        'relevance_score': 1.0,
        'session': session,
        '_search_text': [
          session['title'],
          session['content'],
          session['subject_name'],
          session['subject_code'],
        ].whereType<Object>().join(' '),
      });
    }

    for (final subject in subjects()) {
      result.add({
        'type': 'SUBJECT',
        'relevance_score': 1.0,
        'subject': subject,
        '_search_text': '${subject['code'] ?? ''} ${subject['name'] ?? ''}',
      });
    }

    return result;
  }

  Map<String, dynamic> _search(Map<String, dynamic> query) {
    final keyword = _fold(J.stringOr(query['query']).trim());
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
    if (!supportedTypes.contains(type)) return _emptyPage();

    // ALL cần từ khóa; tìm kiếm theo một loại cụ thể hỗ trợ query rỗng
    // để lấy danh sách mặc định (đặc biệt USER và SESSION).
    if (keyword.isEmpty && type == 'ALL') return _emptyPage();

    final matched = _documents().where((item) {
      if (type != 'ALL' && item['type'] != type) return false;
      final text = _fold(J.stringOr(item['_search_text']));
      return keyword.isEmpty || text.contains(keyword);
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

  Map<String, dynamic> _getSavedSearches() => {
    'saved_searches': [
      for (final item in _savedSearches) Map<String, dynamic>.from(item),
    ],
    'trending_searches': _trendingSearches,
  };

  void _saveSearch(Map<dynamic, dynamic> body) {
    final keyword = J.stringOr(body['query']).trim();
    if (keyword.isEmpty) return;

    _savedSearches.removeWhere(
      (item) =>
          J.stringOr(item['query_text']).toLowerCase() == keyword.toLowerCase(),
    );
    _savedSearches.insert(0, {
      'saved_search_id': _nextSavedSearchId++,
      'query_text': keyword,
      'last_searched_at': _now(),
    });
    if (_savedSearches.length > 20) {
      _savedSearches.removeRange(20, _savedSearches.length);
    }
  }

  void _deleteSavedSearch(String path) {
    final id = int.tryParse(path.split('/').last);
    if (id == null) return;
    _savedSearches.removeWhere((item) => item['saved_search_id'] == id);
  }

  dynamic route(
    String method,
    String path,
    Map<String, dynamic> query,
    Map<dynamic, dynamic> body,
  ) {
    final m = method.toUpperCase();

    if (path == '/search' && m == 'GET') return _search(query);
    if (path == '/search/saved' && m == 'GET') return _getSavedSearches();
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
