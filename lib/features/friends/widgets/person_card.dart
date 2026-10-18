import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/user_avatar.dart';

/// Hàng một người kiểu Facebook: ảnh lớn bên trái, tên + thông tin phụ, và
/// (tuỳ chọn) hai nút hành động ngang hàng bên dưới.
///
/// Dùng cho Gợi ý kết bạn, Lời mời và Danh sách bạn bè.
class PersonCard extends StatelessWidget {
  final String name;
  final String? subtitle;
  final String? avatarUrl;
  final String? frameUrl;
  final VoidCallback? onTap;

  /// Nút chính (vd "Thêm bạn bè", "Xác nhận"). Null = không hiện hàng nút.
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// Nút phụ (vd "Gỡ", "Xoá").
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Khoá nút khi đang xử lý.
  final bool busy;

  /// Thay hàng nút bằng một dòng trạng thái (vd "Đã gửi lời mời").
  final String? statusText;

  /// Widget cuối hàng (vd nút ⋯ ở danh sách bạn bè).
  final Widget? trailing;

  const PersonCard({
    super.key,
    required this.name,
    this.subtitle,
    this.avatarUrl,
    this.frameUrl,
    this.onTap,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
    this.statusText,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasButtons = primaryLabel != null || secondaryLabel != null;

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                avatarUrl: avatarUrl,
                frameUrl: frameUrl,
                name: name,
                size: 64,
                onTap: onTap,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if ((subtitle ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    if (statusText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          statusText!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (hasButtons)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            if (primaryLabel != null)
                              Expanded(
                                child: AppButton(
                                  label: primaryLabel!,
                                  small: true,
                                  onPressed: busy ? null : onPrimary,
                                ),
                              ),
                            if (primaryLabel != null && secondaryLabel != null)
                              const SizedBox(width: 8),
                            if (secondaryLabel != null)
                              Expanded(
                                child: AppButton(
                                  label: secondaryLabel!,
                                  small: true,
                                  variant: AppButtonVariant.neutral,
                                  onPressed: busy ? null : onSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
