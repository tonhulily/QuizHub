import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

/// Kết quả phân trang theo con trỏ (`after`) của backend.
///
/// ```json
/// { "items": [...], "pagination": {"after": 12, "has_next": true} }
/// ```
class CursorPage<T> extends Equatable {
  final List<T> items;
  final String? after;
  final bool hasNext;

  const CursorPage({this.items = const [], this.after, this.hasNext = false});

  factory CursorPage.fromJson(
    dynamic data,
    T Function(Map<String, dynamic> json) itemParser, {
    String itemsKey = 'items',
  }) {
    final map = J.asMap(data) ?? const <String, dynamic>{};
    final pagination = J.asMap(map['pagination']) ?? const <String, dynamic>{};
    final items = J.list<T>(map[itemsKey], itemParser);
    return CursorPage<T>(
      items: items,
      after: J.asString(pagination['after']),
      hasNext: J.asBool(pagination['has_next']),
    );
  }

  /// Bản sao chỉ giữ các phần tử thoả [keep] (giữ nguyên con trỏ phân trang).
  CursorPage<T> filtered(bool Function(T item) keep) => CursorPage<T>(
    items: items.where(keep).toList(),
    after: after,
    hasNext: hasNext,
  );

  @override
  List<Object?> get props => [items, after, hasNext];
}
