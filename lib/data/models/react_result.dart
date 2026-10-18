import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

/// Kết quả `POST /react` (toggle).
class ReactResult extends Equatable {
  /// Cảm xúc hiện tại của mình; rỗng / null nếu vừa gỡ.
  final String? myReaction;
  final Map<String, int> reactionCounts;
  final int totalCount;

  const ReactResult({
    this.myReaction,
    this.reactionCounts = const {},
    this.totalCount = 0,
  });

  bool get reacted => (myReaction ?? '').isNotEmpty && myReaction != 'NONE';

  factory ReactResult.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    final raw = J.asMap(json['reaction_counts']);
    raw?.forEach((k, v) => counts[k] = J.intOr(v));
    return ReactResult(
      myReaction: J.asString(json['my_reaction']),
      reactionCounts: counts,
      totalCount: J.asInt(json['total_count']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [myReaction, reactionCounts, totalCount];
}
