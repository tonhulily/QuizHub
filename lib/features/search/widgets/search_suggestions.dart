import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../data/models/search_models.dart';

class SearchSuggestions extends StatelessWidget {
  final List<SavedSearch> savedSearches;
  final List<String> trendingSearches;
  final bool isLoading;
  final String? error;
  final ValueChanged<String> onSelect;
  final ValueChanged<int> onDelete;

  const SearchSuggestions({
    super.key,
    required this.savedSearches,
    required this.trendingSearches,
    required this.isLoading,
    required this.error,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingMD,
        vertical: DesignTokens.spacingLG,
      ),
      children: [
        if (isLoading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: DesignTokens.spacingMD),
        ],

        // Lịch sử tìm kiếm
        if (savedSearches.isNotEmpty) ...[
          const _SectionHeader(
            title: 'Lịch sử tìm kiếm',
            icon: AppIcons.refresh,
          ),
          const SizedBox(height: DesignTokens.spacingSM),
          ...savedSearches.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              minLeadingWidth: ComponentTokens.circleButton,
              leading: const Icon(
                AppIcons.history,
                color: AppColors.textSecondary,
              ),
              title: Text(
                item.queryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Xóa khỏi lịch sử',
                onPressed: () => onDelete(item.savedSearchId),
                icon: const Icon(
                  AppIcons.close,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () => onSelect(item.queryText),
            ),
          ),
          const SizedBox(height: DesignTokens.spacingLG),
        ],

        // Lỗi tải lịch sử
        if (error != null && savedSearches.isEmpty)
          _HistoryError(message: error!),

        // Xu hướng tìm kiếm
        if (trendingSearches.isNotEmpty) ...[
          const _SectionHeader(
            title: 'Xu hướng tìm kiếm',
            icon: AppIcons.search,
          ),
          const SizedBox(height: DesignTokens.spacingMD),
          Wrap(
            spacing: DesignTokens.spacingSM,
            runSpacing: DesignTokens.spacingSM,
            children: trendingSearches.map((keyword) {
              return ActionChip(
                avatar: const Icon(
                  AppIcons.trendingUp,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                label: Text(keyword),
                onPressed: () => onSelect(keyword),
              );
            }).toList(),
          ),
        ],

        // Trạng thái chưa có dữ liệu
        if (!isLoading &&
            savedSearches.isEmpty &&
            trendingSearches.isEmpty &&
            error == null)
          const Padding(
            padding: EdgeInsets.only(top: DesignTokens.spacingXL * 2),
            child: Center(child: Text('Nhập từ khóa để bắt đầu tìm kiếm')),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: DesignTokens.spacingSM),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _HistoryError extends StatelessWidget {
  final String message;

  const _HistoryError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spacingMD),
      child: Text(
        'Không thể tải lịch sử tìm kiếm: $message',
        style: const TextStyle(color: AppColors.error),
      ),
    );
  }
}
