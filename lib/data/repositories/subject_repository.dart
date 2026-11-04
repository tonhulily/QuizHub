import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/subject_model.dart';

/// Danh mục môn học.
class SubjectRepository {
  final ApiClient _api;

  SubjectRepository(this._api);

  /// Danh mục môn hiếm khi đổi trong một phiên dùng app: giữ trong RAM để bộ
  /// lọc ở nhiều màn hình không gọi lại.
  List<SubjectModel>? _all;

  /// `GET /subjects` - mọi môn, A-Z.
  Future<List<SubjectModel>> all({bool refresh = false}) async {
    final cached = _all;
    if (cached != null && !refresh) return cached;
    final list = await _api.get<List<SubjectModel>>(
      ApiEndpoints.subjects,
      parser: (d) => J.list(d, SubjectModel.fromJson),
    );
    _all = list;
    return list;
  }

  /// `GET /sessions/my-enrolled-subjects` - chỉ môn mình đang học. Form đề
  /// xuất phải dùng danh sách này: đề xuất cho môn khác bị 403.
  Future<List<SubjectModel>> enrolled() => _api.get<List<SubjectModel>>(
    ApiEndpoints.myEnrolledSubjects,
    parser: (d) => J.list(d, SubjectModel.fromJson),
  );
}
