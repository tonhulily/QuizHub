import 'package:flutter/material.dart';

import '../../core/services/blocked_users.dart';
import '../../di/locator.dart';

/// Ẩn cả nội dung đã tải trước khi người dùng chặn tài khoản tác giả.
class BlockedContent extends StatelessWidget {
  final Iterable<int?> userIds;
  final Widget child;
  final Widget blockedChild;

  const BlockedContent({
    super.key,
    required this.userIds,
    required this.child,
    this.blockedChild = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<BlockedUsers>()) return child;
    final blocks = getIt<BlockedUsers>();
    return StreamBuilder<void>(
      stream: blocks.onChanged,
      builder: (context, _) =>
          userIds.any(blocks.contains) ? blockedChild : child,
    );
  }
}
