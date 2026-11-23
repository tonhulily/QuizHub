import '../core/network/api_exception.dart';
import '../core/utils/json_utils.dart';

/// Dữ liệu mẫu cho minigame dự đoán (Game 1, 2, 4) + bảng xếp hạng trong bản
/// xem trước. `PreviewQbank.route` chuyển mọi request `/games/...` sang đây.
///
/// Giả lập các lỗi nghiệp vụ chính của backend (409 cược trùng, 400 loại
/// câu bằng 0) để thử giao diện báo lỗi; dữ liệu chỉ nằm trong RAM.
class PreviewGames {
  /// Trả về nguồn (`LLM` / `HOMO_SAPIENS`) các câu của phiên nếu phiên là
  /// của tôi, null nếu không có.
  final List<String>? Function(int sessionId) mySessionSources;

  PreviewGames({required this.mySessionSources});

  static const List<Map<String, Object>> _game1Classes = [
    {
      'course_class_id': 100,
      'class_code': '171146',
      'semester': '20251',
      'subject_id': 10,
      'subject_name': 'Cấu trúc dữ liệu và thuật toán',
      'lecturer_name': 'ThS. Lê Quang Minh',
    },
    {
      'course_class_id': 101,
      'class_code': '171150',
      'semester': '20251',
      'subject_id': 11,
      'subject_name': 'Nguyên lý hệ điều hành',
      'lecturer_name': 'ThS. Lê Quang Minh',
    },
  ];

  int _nextId = 9000;
  final List<Map<String, dynamic>> _predictions = [
    {
      'prediction_id': 8001,
      'game_type': 'GAME_1_PARTICIPANTS',
      'target_type': 'COURSE_CLASS',
      'target_id': 100,
      'prediction_data': {'predicted_count': 12},
      'actual_data': {'actual_count': 12},
      'status': 'RESOLVED',
      'is_correct': true,
      'created_at': _ago(const Duration(days: 3)),
      'resolved_at': _ago(const Duration(days: 2)),
    },
    {
      'prediction_id': 8002,
      'game_type': 'GAME_1_PARTICIPANTS',
      'target_type': 'COURSE_CLASS',
      'target_id': 101,
      'prediction_data': {'predicted_count': 20},
      'actual_data': {'actual_count': 9},
      'status': 'RESOLVED',
      'is_correct': false,
      'created_at': _ago(const Duration(days: 5)),
      'resolved_at': _ago(const Duration(days: 4)),
    },
  ];

  static String _ago(Duration d) =>
      DateTime.now().toUtc().subtract(d).toIso8601String();

  static Never _conflict(String message) => throw ApiException(
    type: ApiErrorType.business,
    statusCode: 409,
    code: '409',
    message: message,
  );

  static Never _invalid(String message) => throw ApiException(
    type: ApiErrorType.validation,
    statusCode: 400,
    code: '400',
    message: message,
  );

  bool _hasPending(String gameType, int targetId) => _predictions.any(
    (p) =>
        p['game_type'] == gameType &&
        p['target_id'] == targetId &&
        (gameType != 'GAME_1_PARTICIPANTS' || p['status'] == 'PENDING'),
  );

  Map<String, dynamic> _add(
    String gameType,
    String targetType,
    int targetId,
    Map<String, dynamic> data,
  ) {
    final p = <String, dynamic>{
      'prediction_id': _nextId++,
      'game_type': gameType,
      'target_type': targetType,
      'target_id': targetId,
      'prediction_data': data,
      'actual_data': null,
      'status': 'PENDING',
      'is_correct': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'resolved_at': null,
    };
    _predictions.insert(0, p);
    return p;
  }

  dynamic route(String m, String path, Map<String, dynamic> q, Map body) {
    if (path == '/games/prediction/game-1/classes') {
      return [
        for (final c in _game1Classes)
          {
            ...c,
            'already_predicted': _hasPending(
              'GAME_1_PARTICIPANTS',
              c['course_class_id']! as int,
            ),
            'predicted_count': _predictions
                .where(
                  (p) =>
                      p['game_type'] == 'GAME_1_PARTICIPANTS' &&
                      p['status'] == 'PENDING' &&
                      p['target_id'] == c['course_class_id'],
                )
                .map((p) => p['prediction_data']['predicted_count'])
                .firstOrNull,
          },
      ];
    }
    if (path == '/games/prediction/participants' && m == 'POST') {
      final classId = J.intOr(body['course_class_id']);
      final count = J.intOr(body['predicted_count']);
      if (count < 1) _invalid('Số người dự đoán tối thiểu là 1.');
      if (_hasPending('GAME_1_PARTICIPANTS', classId)) {
        _conflict('Bạn đã đặt cược cho lớp này vào ngày mai rồi.');
      }
      return _add('GAME_1_PARTICIPANTS', 'COURSE_CLASS', classId, {
        'predicted_count': count,
      });
    }
    if (path == '/games/prediction/approved-questions' && m == 'POST') {
      final sessionId = J.intOr(body['session_id']);
      final sources = mySessionSources(sessionId);
      if (sources == null) {
        throw const ApiException(
          type: ApiErrorType.notFound,
          statusCode: 404,
          message: 'Không tìm thấy phiên câu hỏi.',
        );
      }
      final llm = J.asInt(body['predicted_llm_count']);
      final human = J.asInt(body['predicted_human_count']);
      final llmTotal = sources.where((s) => s == 'LLM').length;
      final humanTotal = sources.length - llmTotal;
      if ((llm ?? 0) > 0 && llmTotal == 0 ||
          (human ?? 0) > 0 && humanTotal == 0) {
        _invalid('Số câu hỏi đề xuất loại này bằng 0, không thể đặt cược.');
      }
      if (_hasPending('GAME_2_APPROVED_QUESTIONS', sessionId)) {
        _conflict('Bạn đã đặt cược Game 2 cho phiên này rồi.');
      }
      return _add('GAME_2_APPROVED_QUESTIONS', 'SESSION', sessionId, {
        'predicted_llm_count': ?llm,
        'predicted_human_count': ?human,
      });
    }
    if (path == '/games/prediction/bank-size' && m == 'POST') {
      final subjectId = J.intOr(body['subject_id']);
      if (_hasPending('GAME_4_SUBJECT_BANK_SIZE', subjectId)) {
        _conflict('Bạn đã đặt cược cho môn học này rồi.');
      }
      return _add('GAME_4_SUBJECT_BANK_SIZE', 'SUBJECT', subjectId, {
        'predicted_bank_size': J.intOr(body['predicted_bank_size']),
      });
    }
    if (path == '/games/my-predictions') {
      return {
        'contents': _predictions,
        'pagination': {
          'before': null,
          'after': null,
          'has_prev': false,
          'has_next': false,
        },
      };
    }
    if (path == '/games/leaderboard') {
      const names = [
        'Trần Minh Khoa',
        'Lê Thu Hà',
        'Nguyễn Văn An',
        'Phạm Quốc Bảo',
        'Đỗ Hải Yến',
        'Vũ Đức Thắng',
      ];
      final bySubject = J.stringOr(q['period']).toUpperCase() == 'SUBJECT';
      final entries = [
        for (var i = 0; i < names.length; i++)
          {
            'rank': i + 1,
            'user_id': i == 2 ? 1 : 100 + i,
            'user_code': '2021${(1000 + i * 37).toString()}',
            'full_name': names[i],
            'avatar_url': '',
            'frame_url': '',
            'total_points': (bySubject ? 80 : 160) - i * 12.5,
            'is_current_user': i == 2,
          },
      ];
      return {
        'entries': entries,
        'my_rank': {
          'rank': 3,
          'total_points': entries[2]['total_points'],
          'top_percent': 5.0,
          'total_participants': 60,
          'full_name': 'Nguyễn Văn An',
          'avatar_url': '',
          'frame_url': '',
        },
        'pagination': {
          'before': null,
          'after': null,
          'has_prev': false,
          'has_next': false,
        },
      };
    }
    return null;
  }
}
