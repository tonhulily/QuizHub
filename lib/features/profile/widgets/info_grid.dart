import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';

/// Ai xem được một mục thông tin (chỉ để hiển thị biểu tượng, quyền thật do
/// server quyết định).
enum InfoAudience { everyone, onlyMe }

/// Một ô thông tin: icon + nhãn + giá trị.
class InfoItem {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  /// Null = không hiện biểu tượng quyền xem.
  final InfoAudience? audience;

  /// Ép ô rộng hết hàng; mặc định tự rộng khi giá trị dài.
  final bool? wide;

  const InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.primary600,
    this.audience,
    this.wide,
  });

  bool get isWide => wide ?? value.length > 22;
}

/// Lưới thông tin 2 cột (ô giá trị dài tự chiếm cả hàng). Thay cho danh sách
/// dọc: nhiều thông tin vẫn gọn và dễ quét mắt.
class InfoGrid extends StatelessWidget {
  final List<InfoItem> items;
  final double spacing;

  const InfoGrid({super.key, required this.items, this.spacing = 10});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    // Xếp để không bị khoảng trống: ô ngắn đi theo cặp trước, ô dài (chiếm cả
    // hàng) xuống sau; nếu số ô ngắn lẻ thì ô cuối giãn hết hàng.
    final shorts = [
      for (final i in items)
        if (!i.isWide) i,
    ];
    final wides = [
      for (final i in items)
        if (i.isWide) i,
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final half = (c.maxWidth - spacing) / 2;
        final children = <Widget>[
          for (var i = 0; i < shorts.length; i++)
            SizedBox(
              width: (i == shorts.length - 1 && shorts.length.isOdd)
                  ? c.maxWidth
                  : half,
              child: _InfoTile(item: shorts[i]),
            ),
          for (final item in wides)
            SizedBox(
              width: c.maxWidth,
              child: _InfoTile(item: item),
            ),
        ];
        return Wrap(spacing: spacing, runSpacing: spacing, children: children);
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final InfoItem item;
  const _InfoTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audience = item.audience;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 22, color: item.color),
              ),
              const Spacer(),
              if (audience != null)
                Tooltip(
                  message: audience == InfoAudience.onlyMe
                      ? 'Chỉ mình bạn thấy'
                      : 'Hiển thị với mọi người',
                  child: Icon(
                    audience == InfoAudience.onlyMe
                        ? AppIcons.audienceOnlyMe
                        : AppIcons.audienceEveryone,
                    size: 16,
                    color: audience == InfoAudience.onlyMe
                        ? AppColors.warningDark
                        : AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            item.value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
