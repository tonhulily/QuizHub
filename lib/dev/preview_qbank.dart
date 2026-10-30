import '../core/utils/json_utils.dart';

/// Dữ liệu mẫu cho module Ngân hàng câu hỏi + Đề thi + AI trong bản xem trước
/// (`lib/main_preview.dart`). Tách khỏi `PreviewBackend` để file đó khỏi phình;
/// `PreviewBackend._route` hỏi lớp này trước tiên.
///
/// Khác backend thật: mọi vai trò đều gọi được (kể cả API chỉ dành cho giảng
/// viên), không giả lập mã lỗi (409 trả lời lại, 403...) và dữ liệu chỉ nằm
/// trong RAM. JSON bám theo schema Swagger; khi có JSON thật trong
/// `docs/api-samples/` thì sửa cho khớp.
class PreviewQbank {
  /// Trả về khi request không thuộc module này.
  static const Object unhandled = Object();

  /// Id người dùng mẫu đang đăng nhập (giống `PreviewBackend`).
  static const int _meId = 1;

  static const List<Map<String, Object>> _subjects = [
    {
      'subject_id': 10,
      'code': 'IT3011',
      'name': 'Cấu trúc dữ liệu và thuật toán',
    },
    {'subject_id': 11, 'code': 'IT3070', 'name': 'Nguyên lý hệ điều hành'},
    {'subject_id': 12, 'code': 'IT3180', 'name': 'Nhập môn công nghệ phần mềm'},
  ];
  static const Set<int> _enrolledIds = {10, 11};

  static const List<Map<String, Object>> _classes = [
    {
      'course_class_id': 100,
      'class_code': '171146',
      'subject_id': 10,
      'subject_code': 'IT3011',
      'subject_name': 'Cấu trúc dữ liệu và thuật toán',
      'semester_id': 1,
      'semester_name': '20251',
      'lecturer_id': 3,
      'lecturer_name': 'ThS. Lê Quang Minh',
      'total_students': 65,
    },
    {
      'course_class_id': 101,
      'class_code': '171150',
      'subject_id': 11,
      'subject_code': 'IT3070',
      'subject_name': 'Nguyên lý hệ điều hành',
      'semester_id': 1,
      'semester_name': '20251',
      'lecturer_id': 3,
      'lecturer_name': 'ThS. Lê Quang Minh',
      'total_students': 58,
    },
  ];

  int _nextId = 5000;
  final Map<int, Map<String, dynamic>> _sessions = {};
  final Map<int, Map<String, dynamic>> _questions = {};

  /// questionId -> các phương án tôi đã chọn
  final Map<int, List<String>> _answers = {};
  final Map<int, List<Map<String, dynamic>>> _ratings = {};

  /// editLogId -> bản gợi ý của AI đang chờ áp dụng
  final Map<int, Map<String, dynamic>> _aiLogs = {};
  final Map<int, Map<String, dynamic>> _exams = {};

  PreviewQbank() {
    Map<String, dynamic> opt(String key, String text, [bool correct = false]) =>
        {'key': key, 'text': text, 'is_correct': correct};

    _seedSession(
      1,
      author: 2,
      subjectId: 10,
      status: 'RESOLVED',
      title: 'Ôn tập cây cân bằng AVL',
      daysAgo: 20,
      reviewedBy: 'ThS. Lê Quang Minh',
      questions: [
        {
          'question_id': 101,
          'content':
              'Độ phức tạp thời gian của thao tác tìm kiếm trên cây AVL có n nút là?',
          'options': [
            opt('A', 'O(1)'),
            opt('B', 'O(log n)', true),
            opt('C', 'O(n)'),
            opt('D', 'O(n log n)'),
          ],
          'explanation':
              'Cây AVL luôn cân bằng nên chiều cao là O(log n), tìm kiếm đi '
              'từ gốc xuống lá.',
          'status': 'APPROVED',
          'difficulty': 'EASY',
          'topic': 'Cây cân bằng',
        },
        {
          'question_id': 102,
          'content':
              'Sau khi chèn vào cây AVL, cần tối đa bao nhiêu phép quay để cân '
              'bằng lại?',
          'options': [
            opt('A', '1 phép quay đơn hoặc 1 phép quay kép', true),
            opt('B', 'O(log n) phép quay'),
            opt('C', 'Không cần quay'),
            opt('D', 'n phép quay'),
          ],
          'explanation':
              'Chèn chỉ làm mất cân bằng một nút thấp nhất trên đường đi; quay '
              'tại nút đó là đủ.',
          'status': 'APPROVED',
          'difficulty': 'MEDIUM',
          'topic': 'Cây cân bằng',
        },
        {
          'question_id': 103,
          'content': 'Cây AVL là cây nhị phân đầy đủ. Đúng hay sai?',
          'options': [opt('A', 'Đúng'), opt('B', 'Sai', true)],
          'explanation': 'AVL chỉ yêu cầu chênh lệch chiều cao không quá 1.',
          'status': 'REJECTED',
          'difficulty': 'EASY',
          'topic': 'Cây cân bằng',
        },
      ],
    );
    _seedSession(
      2,
      author: 4,
      subjectId: 11,
      status: 'RESOLVED',
      title: 'Định thời CPU - chương 5',
      daysAgo: 12,
      reviewedBy: 'ThS. Lê Quang Minh',
      questions: [
        {
          'question_id': 201,
          'content':
              'Thuật toán định thời nào có thể gây đói (starvation) cho tiến '
              'trình dài?',
          'options': [
            opt('A', 'Round Robin'),
            opt('B', 'Shortest Job First', true),
            opt('C', 'First Come First Served'),
            opt('D', 'Không thuật toán nào'),
          ],
          'explanation':
              'SJF luôn ưu tiên tiến trình ngắn, tiến trình dài có thể chờ mãi.',
          'status': 'APPROVED',
          'difficulty': 'MEDIUM',
          'topic': 'Định thời CPU',
          'source': 'LLM',
        },
        {
          'question_id': 202,
          'content':
              'Quantum quá lớn khiến Round Robin gần giống thuật toán nào?',
          'options': [
            opt('A', 'FCFS', true),
            opt('B', 'SJF'),
            opt('C', 'Priority'),
            opt('D', 'Multilevel Queue'),
          ],
          'explanation':
              'Mỗi tiến trình chạy xong trong một lượt nên thứ tự là đến trước '
              'phục vụ trước.',
          'status': 'APPROVED',
          'difficulty': 'HARD',
          'topic': 'Định thời CPU',
        },
      ],
    );
    _seedSession(
      3,
      author: _meId,
      subjectId: 10,
      status: 'PENDING',
      title: 'Bảng băm và xử lý đụng độ',
      daysAgo: 1,
      questions: [
        {
          'question_id': 301,
          'content': 'Kỹ thuật nào xử lý đụng độ bằng danh sách liên kết?',
          'options': [
            opt('A', 'Separate chaining', true),
            opt('B', 'Linear probing'),
            opt('C', 'Quadratic probing'),
            opt('D', 'Double hashing'),
          ],
          'explanation': 'Mỗi ô của bảng giữ một danh sách các khoá cùng băm.',
          'status': 'PENDING',
        },
        {
          'question_id': 302,
          'content': 'Hệ số tải (load factor) của bảng băm được tính bằng?',
          'options': [
            opt('A', 'Số khoá / số ô', true),
            opt('B', 'Số ô / số khoá'),
            opt('C', 'Số đụng độ / số khoá'),
            opt('D', 'Số ô trống / số ô'),
          ],
          'status': 'PENDING',
        },
      ],
    );
    _seedSession(
      4,
      author: _meId,
      subjectId: 11,
      status: 'REVIEWING',
      title: 'Bộ nhớ ảo',
      daysAgo: 3,
      questions: [
        {
          'question_id': 401,
          'content': 'Lỗi trang (page fault) xảy ra khi nào?',
          'options': [
            opt('A', 'Trang cần truy cập không có trong bộ nhớ chính', true),
            opt('B', 'Bộ nhớ chính đầy'),
            opt('C', 'Tiến trình truy cập vùng nhớ của tiến trình khác'),
            opt('D', 'TLB bị xoá'),
          ],
          'status': 'PENDING',
        },
      ],
    );
    _seedSession(
      5,
      author: _meId,
      subjectId: 10,
      status: 'RESOLVED',
      title: 'Sắp xếp nhanh',
      daysAgo: 30,
      reviewedBy: 'ThS. Lê Quang Minh',
      questions: [
        {
          'question_id': 501,
          'content': 'Độ phức tạp xấu nhất của Quick Sort là?',
          'options': [
            opt('A', 'O(n log n)'),
            opt('B', 'O(n^2)', true),
            opt('C', 'O(n)'),
            opt('D', 'O(log n)'),
          ],
          'explanation':
              'Khi chốt luôn là phần tử nhỏ nhất / lớn nhất, mỗi lần chỉ bớt '
              'được một phần tử.',
          'status': 'APPROVED',
          'difficulty': 'MEDIUM',
          'topic': 'Sắp xếp',
        },
        {
          'question_id': 502,
          'content': 'Quick Sort là thuật toán sắp xếp ổn định?',
          'options': [opt('A', 'Có'), opt('B', 'Không', true)],
          'status': 'REJECTED',
          'difficulty': 'EASY',
          'topic': 'Sắp xếp',
        },
      ],
    );

    _ratings[101] = [
      {
        'user_id': 4,
        'rating': 4,
        'is_error': false,
        'comment': 'Câu hỏi rõ ràng, giải thích dễ hiểu.',
        'created_at': _ago(5),
      },
      {
        'user_id': 6,
        'rating': 3,
        'is_error': false,
        'comment': 'Hơi cơ bản.',
        'created_at': _ago(2),
      },
    ];

    _exams[1] = {
      'exam_id': 1,
      'title': 'Đề giữa kỳ IT3011 - 20251',
      'subject_id': 10,
      'question_ids': [101, 102, 501],
      'created_at': _ago(4),
    };
  }

  static String _ago(int days) =>
      DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();

  static String _now() => DateTime.now().toUtc().toIso8601String();

  void _seedSession(
    int id, {
    required int author,
    required int subjectId,
    required String status,
    required String title,
    required int daysAgo,
    String? reviewedBy,
    required List<Map<String, dynamic>> questions,
  }) {
    final created = _ago(daysAgo);
    for (final q in questions) {
      _questions[q['question_id'] as int] = {
        'session_id': id,
        'subject_id': subjectId,
        'image_urls': <String>[],
        'source': 'HOMO_SAPIENS',
        'confidence': 3.0,
        'difficulty': 'UNCLASSIFIED',
        'created_at': created,
        'updated_at': created,
        ...q,
      };
    }
    _sessions[id] = {
      'session_id': id,
      'session_code': '${_subject(subjectId)['code']}_PREVIEW_$id',
      'title': title,
      'content': 'Bộ câu hỏi mẫu cho bản xem trước.',
      'subject_id': subjectId,
      'author_id': author,
      'status': status,
      'created_at': created,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedBy == null ? null : _ago(daysAgo - 1),
      'react_count': 3,
      'comment_count': 1,
      'question_ids': [for (final q in questions) q['question_id'] as int],
    };
  }

  Map<String, Object> _subject(int id) => _subjects.firstWhere(
    (s) => s['subject_id'] == id,
    orElse: () => _subjects.first,
  );

  List<Map<String, dynamic>> _questionsOf(dynamic ids) => [
    for (final id in J.asList(ids)) ?_questions[id],
  ];

  List<String> _correctKeys(Map<String, dynamic> q) => [
    for (final o in J.asList(q['options']))
      if (J.asBool(J.asMap(o)?['is_correct'])) J.stringOr(J.asMap(o)?['key']),
  ];

  // ------------------------------------------------------------------
  // JSON trả về (theo schema Swagger)
  // ------------------------------------------------------------------

  Map<String, dynamic> _summary(Map<String, dynamic> s) {
    final subject = _subject(s['subject_id'] as int);
    return {
      'session_id': s['session_id'],
      'session_code': s['session_code'],
      'title': s['title'],
      'content': s['content'],
      'subject_id': subject['subject_id'],
      'subject_name': subject['name'],
      'subject_code': subject['code'],
      'question_counts': J.asList(s['question_ids']).length,
      'status': s['status'],
      'created_at': s['created_at'],
      'react_count': s['react_count'] ?? 0,
      'comment_count': s['comment_count'] ?? 0,
    };
  }

  Map<String, dynamic> _sessionPage(
    Iterable<Map<String, dynamic>> source,
    Map<String, dynamic> q,
  ) {
    final status = J.asString(q['status']);
    final subjectId = J.asInt(q['subject_id']);
    final list =
        source
            .where((s) => status == null || s['status'] == status)
            .where((s) => subjectId == null || s['subject_id'] == subjectId)
            .toList()
          ..sort(
            (a, b) =>
                (b['session_id'] as int).compareTo(a['session_id'] as int),
          );
    return {
      'contents': [for (final s in list) _summary(s)],
      'pagination': {
        'before': null,
        'after': null,
        'has_prev': false,
        'has_next': false,
      },
    };
  }

  Map<String, dynamic> _authorQuestion(Map<String, dynamic> q) => {
    'question_id': q['question_id'],
    'content': q['content'],
    'image_urls': q['image_urls'],
    'options': q['options'],
    'explanation': q['explanation'],
    'source': q['source'],
    'confidence_score': q['confidence'],
    'status': q['status'],
    'react_count': 0,
    'comment_count': 0,
    'rating_count': (_ratings[q['question_id']] ?? const []).length,
  };

  Map<String, dynamic> _practiceQuestion(Map<String, dynamic> q) {
    final id = q['question_id'] as int;
    final answered = _answers.containsKey(id);
    final correct = _correctKeys(q);
    return {
      'question_id': id,
      'question_code': 'Q$id',
      'content': q['content'],
      'image_urls': q['image_urls'],
      // Chưa trả lời thì backend ẩn is_correct để không lộ đáp án
      'options': [
        for (final o in J.asList(q['options']))
          answered ? o : {'key': o['key'], 'text': o['text']},
      ],
      'source': q['source'],
      'created_at': q['created_at'],
      'updated_at': q['updated_at'],
      'my_interaction': {
        'answered': answered,
        'rated': (_ratings[id] ?? const []).any((r) => r['user_id'] == _meId),
      },
      'hidden_fields': {
        'correct_answer': answered ? correct.join(',') : null,
        'explanation': answered ? q['explanation'] : null,
      },
      'react_count': 2,
      'comment_count': 0,
      'rating_count': (_ratings[id] ?? const []).length,
    };
  }

  Map<String, dynamic> _examItem(Map<String, dynamic> e) {
    final qs = _questionsOf(e['question_ids']);
    final subject = _subject(e['subject_id'] as int);
    int count(String d) => qs.where((q) => q['difficulty'] == d).length;
    return {
      'exam_id': e['exam_id'],
      'title': e['title'],
      'subject_name': subject['name'],
      'question_count': qs.length,
      'created_at': e['created_at'],
      'statistic': {
        'easy_count': count('EASY'),
        'medium_count': count('MEDIUM'),
        'hard_count': count('HARD'),
        'unclassified_count': count('UNCLASSIFIED'),
      },
    };
  }

  Map<String, dynamic> _examDetail(Map<String, dynamic> e) {
    final qs = _questionsOf(e['question_ids']);
    return {
      ..._examItem(e),
      'questions': [
        for (var i = 0; i < qs.length; i++)
          {
            'order': i + 1,
            'question_id': qs[i]['question_id'],
            'content': qs[i]['content'],
            'image_urls': qs[i]['image_urls'],
            'options': qs[i]['options'],
            'difficulty': qs[i]['difficulty'],
            'topic': qs[i]['topic'],
          },
      ],
    };
  }

  /// Ghi nội dung form tạo / sửa phiên vào [s]. Câu không gửi lên thì bị bỏ
  /// khỏi phiên (backend thật chưa rõ, xem API_CONTRACT.md mục 6).
  void _applyDraft(Map<String, dynamic> s, Map<dynamic, dynamic> body) {
    for (final key in const ['title', 'content', 'source_url']) {
      if (body[key] != null) s[key] = body[key];
    }
    if (J.asInt(body['subject_id']) case final subjectId?) {
      s['subject_id'] = subjectId;
    }
    final ids = <int>[];
    for (final q in J.list(body['questions'], (m) => m)) {
      final id = J.asInt(q['question_id']) ?? _nextId++;
      final old = _questions[id];
      _questions[id] = {
        'question_id': id,
        'session_id': s['session_id'],
        'subject_id': s['subject_id'],
        'content': J.stringOr(q['content']),
        'image_urls': J.asList(q['media_urls']),
        'options': J.list(
          q['options'],
          (o) => <String, dynamic>{
            'key': J.stringOr(o['key']),
            'text': J.stringOr(o['text']),
            'is_correct': J.asBool(o['is_correct']),
          },
        ),
        'explanation': J.asString(q['explanation']),
        'source':
            J.asString(q['source']) ??
            (J.asBool(q['llm_generated']) ? 'LLM' : 'HOMO_SAPIENS'),
        'confidence': J.asDouble(q['confidence']),
        'status': 'PENDING',
        'difficulty': 'UNCLASSIFIED',
        'created_at': old?['created_at'] ?? _now(),
        'updated_at': _now(),
      };
      ids.add(id);
    }
    s['question_ids'] = ids;
  }

  // ------------------------------------------------------------------
  // Định tuyến
  // ------------------------------------------------------------------

  dynamic route(
    String m,
    String path,
    Map<String, dynamic> q,
    Map<dynamic, dynamic> body,
  ) {
    final seg = path.split('/'); // ['', 'sessions', '12', 'questions']

    if (path == '/subjects') return _subjects;
    if (path == '/sessions/my-enrolled-subjects') {
      return [
        for (final s in _subjects)
          if (_enrolledIds.contains(s['subject_id'])) s,
      ];
    }

    // ---- Phiên đề xuất của tôi ----
    if (path == '/sessions/my-submissions' && m == 'GET') {
      return _sessionPage(
        _sessions.values.where((s) => s['author_id'] == _meId),
        q,
      );
    }
    if (seg.length == 4 && seg[2] == 'my-submissions') {
      final id = int.tryParse(seg[3]);
      final s = _sessions[id];
      if (s == null) return null;
      if (m == 'DELETE') {
        _sessions.remove(id);
        return null;
      }
      if (m == 'PUT') {
        _applyDraft(s, body);
        return null;
      }
      return {
        ..._summary(s),
        'source_url': s['source_url'],
        'reviewed_by_lecturer': s['reviewed_by'],
        'reviewed_at': s['reviewed_at'],
        'questions': [
          for (final x in _questionsOf(s['question_ids'])) _authorQuestion(x),
        ],
      };
    }
    if (path == '/sessions/propose' && m == 'POST') {
      final id = _nextId++;
      final subjectId = J.intOr(body['subject_id'], 10);
      final s = <String, dynamic>{
        'session_id': id,
        'session_code': '${_subject(subjectId)['code']}_PREVIEW_$id',
        'subject_id': subjectId,
        'author_id': _meId,
        'status': 'PENDING',
        'created_at': _now(),
        'react_count': 0,
        'comment_count': 0,
      };
      _applyDraft(s, body);
      _sessions[id] = s;
      return {
        'session_id': id,
        'session_code': s['session_code'],
        'subject_id': s['subject_id'],
        'question_count': J.asList(s['question_ids']).length,
        'status': 'PENDING',
        'created_at': s['created_at'],
      };
    }

    // ---- Duyệt ngân hàng ----
    if (seg.length == 4 && seg[1] == 'users' && seg[3] == 'sessions') {
      final userId = int.tryParse(seg[2]);
      return _sessionPage(
        _sessions.values.where(
          (s) =>
              s['author_id'] == userId &&
              (userId == _meId || s['status'] == 'RESOLVED'),
        ),
        q,
      );
    }
    if (path == '/search' &&
        J.stringOr(q['type']).toUpperCase() == 'QUESTION') {
      final keyword = J.stringOr(q['query']).toLowerCase().trim();
      final list = _questions.values.where((x) {
        final s = _sessions[x['session_id']];
        if (s == null || s['status'] != 'RESOLVED') return false;
        if (keyword.isEmpty) return true;
        final subject = _subject(x['subject_id'] as int);
        return '${x['content']} ${subject['name']} ${subject['code']}'
            .toLowerCase()
            .contains(keyword);
      }).toList();
      return {
        'items': [
          for (final x in list)
            {
              'type': 'QUESTION',
              'relevance_score': 1.0,
              'question': {
                'question_id': x['question_id'],
                'question_code': x['question_code'],
                'subject_id': x['subject_id'],
                'subject_name': _subject(x['subject_id'] as int)['name'],
                'status': 'APPROVED',
                'difficulty': x['difficulty'],
                'content': x['content'],
                // Kết quả tìm kiếm không lộ đáp án
                'options': [
                  for (final o in J.asList(x['options']))
                    {'key': J.asMap(o)?['key'], 'text': J.asMap(o)?['text']},
                ],
                'rating_count': (_ratings[x['question_id']] ?? const []).length,
                'comment_count': 0,
                'created_at': x['created_at'],
                // Swagger chưa có; giả lập backend đã bổ sung để thử luồng mở
                // phiên từ câu hỏi
                'session_id': x['session_id'],
              },
            },
        ],
        'pagination': {
          'before': null,
          'after': null,
          'has_prev': false,
          'has_next': false,
        },
        'total_hits': list.length,
      };
    }
    if (path == '/search' && J.stringOr(q['type']).toUpperCase() == 'SESSION') {
      final keyword = J.stringOr(q['query']).toLowerCase().trim();
      final list = _sessions.values.where((s) {
        if (s['status'] != 'RESOLVED') return false;
        if (keyword.isEmpty) return true;
        final subject = _subject(s['subject_id'] as int);
        return '${s['title']} ${subject['name']} ${subject['code']}'
            .toLowerCase()
            .contains(keyword);
      }).toList();
      return {
        'items': [
          for (final s in list)
            {
              'type': 'SESSION',
              'relevance_score': 1.0,
              'session': {
                ..._summary(s),
                'question_count': J.asList(s['question_ids']).length,
              },
            },
        ],
        'pagination': {
          'before': null,
          'after': null,
          'has_prev': false,
          'has_next': false,
        },
        'total_hits': list.length,
      };
    }
    if (seg.length == 4 && seg[1] == 'sessions' && seg[3] == 'questions') {
      final s = _sessions[int.tryParse(seg[2])];
      if (s == null) return null;
      final mine = s['author_id'] == _meId;
      final qs = _questionsOf(
        s['question_ids'],
      ).where((x) => mine || x['status'] == 'APPROVED').toList();
      final subject = _subject(s['subject_id'] as int);
      return {
        'session_id': s['session_id'],
        'session_code': s['session_code'],
        'title': s['title'],
        'content': s['content'],
        'subject_id': subject['subject_id'],
        'subject_name': subject['name'],
        'subject_code': subject['code'],
        'created_at': s['created_at'],
        'total_questions': qs.length,
        'questions': [for (final x in qs) _practiceQuestion(x)],
      };
    }

    // ---- Tương tác với một câu hỏi ----
    if (seg.length == 4 && seg[1] == 'questions') {
      final id = int.tryParse(seg[2]);
      final question = _questions[id];
      if (id == null || question == null) return null;
      switch (seg[3]) {
        case 'answer':
          {
            final selected = [
              for (final k in J.asList(body['selected_options'])) J.stringOr(k),
            ];
            _answers[id] = selected;
            final correct = _correctKeys(question);
            return {
              'is_correct':
                  selected.length == correct.length &&
                  selected.toSet().containsAll(correct),
              'correct_answer': correct.join(','),
              'explanation': question['explanation'],
            };
          }
        case 'rate':
          {
            final list = _ratings.putIfAbsent(id, () => []);
            final isError = J.asBool(body['is_error']);
            list.removeWhere((r) => r['user_id'] == _meId);
            list.insert(0, {
              'user_id': _meId,
              'rating': isError ? 0 : J.intOr(body['rating']),
              'is_error': isError,
              'comment': J.asString(body['comment']),
              'created_at': _now(),
            });
            final sum = list.fold<num>(0, (a, r) => a + (r['rating'] as num));
            return {
              'new_avg_rating': sum / list.length,
              'new_rating_count': list.length,
            };
          }
        case 'ratings':
          {
            return {
              'items': _ratings[id] ?? const [],
              'pagination': {'after': null, 'has_next': false},
            };
          }
        case 'statistics':
          {
            final ratings = _ratings[id] ?? const <Map<String, dynamic>>[];
            final correct = _correctKeys(question);
            final picks = {
              for (final o in J.asList(question['options']))
                J.stringOr(o['key']): correct.contains(o['key']) ? 30 : 7,
            };
            final total = picks.values.fold<int>(0, (a, b) => a + b);
            final right = picks.entries
                .where((e) => correct.contains(e.key))
                .fold<int>(0, (a, e) => a + e.value);
            final sum = ratings.fold<num>(
              0,
              (a, r) => a + (r['rating'] as num),
            );
            return {
              'total_answer': total,
              'correct_rate': total == 0 ? 0 : right / total,
              'option_distribution': picks,
              'rating_summary': {
                'avg_rating': ratings.isEmpty ? 0 : sum / ratings.length,
                'total_ratings': ratings.length,
                'distribution': {
                  for (var i = 0; i <= 4; i++)
                    '$i': ratings.where((r) => r['rating'] == i).length,
                },
              },
            };
          }
        case 'ai-refine':
          {
            final logId = _nextId++;
            final base =
                J.asString(question['explanation']) ??
                'đối chiếu từng phương án với định nghĩa trong giáo trình.';
            final suggestion = <String, dynamic>{
              'content': 'Chọn đáp án đúng: ${question['content']}',
              'options': question['options'],
              'explanation': 'Giải thích do AI viết lại: $base',
            };
            _aiLogs[logId] = suggestion;
            return {
              'edit_log_id': logId,
              'suggested_question': {...suggestion, 'refusal_reason': null},
              'hallucination_audit': {
                'is_hallucinated': false,
                'confidence_score': 0.92,
                'belief_tree_depth': 3,
                'violations': const [],
              },
              'ai_metadata': {
                'model': 'preview-model',
                'tokens_used': 380,
                'processing_time_ms': 1200,
              },
            };
          }
        case 'ai-apply':
          {
            final approve = J.asBool(body['approve']);
            final log = _aiLogs.remove(J.asInt(body['edit_log_id']));
            if (approve && log != null) {
              question.addAll(log);
              question['updated_at'] = _now();
            }
            return {
              'question_id': id,
              'status': approve ? 'APPLIED' : 'DISCARDED',
              'confidence_score': 0.92,
              'hallucination': false,
            };
          }
      }
    }

    // ---- Đề thi (backend thật: chỉ giảng viên) ----
    if (path == '/lecturer/course-classes/my-classes') return _classes;
    if (path == '/exams/generate' && m == 'POST') {
      final subjectId = J.intOr(body['subject_id'], 10);
      final count = J.intOr(body['question_count'], 10);
      final id = _nextId++;
      final exam = <String, dynamic>{
        'exam_id': id,
        'title': J.stringOr(
          body['title'],
          'Đề ${_subject(subjectId)['code']} số $id',
        ),
        'subject_id': subjectId,
        'question_ids': [
          for (final x in _questions.values)
            if (x['subject_id'] == subjectId && x['status'] == 'APPROVED')
              x['question_id'] as int,
        ].take(count).toList(),
        'created_at': _now(),
      };
      _exams[id] = exam;
      return _examDetail(exam);
    }
    if (path == '/exams/my-exams') {
      final list = _exams.values.toList()
        ..sort((a, b) => (b['exam_id'] as int).compareTo(a['exam_id'] as int));
      return {
        'items': [for (final e in list) _examItem(e)],
        'pagination': {'after': null, 'has_next': false},
      };
    }
    if (seg.length >= 3 && seg[1] == 'exams') {
      final id = int.tryParse(seg[2]);
      final exam = _exams[id];
      if (exam == null) return null;
      if (seg.length == 4 && seg[3] == 'export') {
        final ext = J.stringOr(q['format'], 'pdf') == 'pdf' ? 'pdf' : 'xlsx';
        return {
          'download_url': 'https://example.com/preview/exam-$id.$ext',
          'file_size_mb': 0.4,
          'questions_count': J.asList(exam['question_ids']).length,
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        };
      }
      return _examDetail(exam);
    }
    return unhandled;
  }
}
