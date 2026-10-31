import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

/// Môn học (`SubjectResponse` của `GET /subjects` và
/// `GET /sessions/my-enrolled-subjects`).
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
