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

  /// `GET /sessions/my-enrolled-course-classes` - lớp học phần của mình (cả
  /// học kỳ cũ). Form đề xuất chỉ dùng lớp có `canPropose`.
  Future<List<EnrolledCourseClass>> enrolledClasses() =>
      _api.get<List<EnrolledCourseClass>>(
        ApiEndpoints.myEnrolledCourseClasses,
        parser: (d) => J.list(d, EnrolledCourseClass.fromJson),
      );

  /// Môn mình đang / đã học: gộp [enrolledClasses] theo `subject_id`, giữ thứ
  /// tự server trả về. [currentSemester]: chỉ lớp của học kỳ đang hoạt động
  /// (minigame 4, xếp hạng theo môn).
  Future<List<SubjectModel>> enrolled({bool currentSemester = false}) async {
    final classes = await enrolledClasses();
    final seen = <int>{};
    return [
      for (final c in classes)
        if ((!currentSemester || c.activeSemester) &&
            c.subjectId > 0 &&
            seen.add(c.subjectId))
          c.subject,
    ];
  }
}
