import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

/// Môn học (`SubjectResponse` của `GET /subjects`; môn đang học được gộp từ
/// `GET /sessions/my-enrolled-course-classes`).
class SubjectModel extends Equatable {
  final int subjectId;
  final String code;
  final String name;

  const SubjectModel({
    required this.subjectId,
    required this.code,
    required this.name,
  });

  /// "IT3180 · Nhập môn Công nghệ phần mềm"
  String get label => code.isEmpty ? name : '$code · $name';

  factory SubjectModel.fromJson(Map<String, dynamic> json) => SubjectModel(
    subjectId: J.intOr(json['subject_id'] ?? json['id']),
    // Kết quả tìm kiếm dùng subject_code / subject_name thay cho code / name
    code: J.stringOr(json['code'] ?? json['subject_code']),
    name: J.stringOr(json['name'] ?? json['subject_name'], 'Môn học'),
  );

  @override
  List<Object?> get props => [subjectId, code, name];
}

/// Lớp học phần mình đang / đã học (`CourseClassOptionResponse` của
/// `GET /sessions/my-enrolled-course-classes`). Chỉ lớp của học kỳ hiện tại
/// có [canPropose] = true.
class EnrolledCourseClass extends Equatable {
  final int courseClassId;
  final String classCode;
  final int subjectId;
  final String subjectCode;
  final String subjectName;
  final String? semesterName;
  final bool activeSemester;
  final bool canPropose;

  const EnrolledCourseClass({
    required this.courseClassId,
    required this.classCode,
    required this.subjectId,
    this.subjectCode = '',
    this.subjectName = 'Môn học',
    this.semesterName,
    this.activeSemester = false,
    this.canPropose = false,
  });

  SubjectModel get subject =>
      SubjectModel(subjectId: subjectId, code: subjectCode, name: subjectName);

  /// "171146 · IT3180 · Nhập môn Công nghệ phần mềm"
  String get label =>
      classCode.isEmpty ? subject.label : '$classCode · ${subject.label}';

  factory EnrolledCourseClass.fromJson(Map<String, dynamic> json) =>
      EnrolledCourseClass(
        courseClassId: J.intOr(json['course_class_id'] ?? json['id']),
        classCode: J.stringOr(json['class_code']),
        subjectId: J.intOr(json['subject_id']),
        subjectCode: J.stringOr(json['subject_code']),
        subjectName: J.stringOr(json['subject_name'], 'Môn học'),
        semesterName: J.asString(json['semester_name']),
        activeSemester: json['active_semester'] == true,
        canPropose: json['can_propose'] == true,
      );

  @override
  List<Object?> get props => [
    courseClassId,
    classCode,
    subjectId,
    semesterName,
    activeSemester,
    canPropose,
  ];
}
