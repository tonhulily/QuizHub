import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        if (isLoading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
        ],
  
        if (savedSearches.isNotEmpty) ...[
          _SectionHeader(
            title: 'Lịch sử tìm kiếm',
            icon: Icons.history,
          ),
          const SizedBox(height: 8),
          ...savedSearches.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text(
                item.queryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Xóa khỏi lịch sử',
                onPressed: () => onDelete(item.savedSearchId),
                icon: const Icon(Icons.close, size: 20),
              ),
              onTap: () => onSelect(item.queryText),
            ),
          ),
          const SizedBox(height: 24),
        ],
  
        if (error != null && savedSearches.isEmpty)
          _HistoryError(message: error!),
  
        if (trendingSearches.isNotEmpty) ...[
          _SectionHeader(
            title: 'Xu hướng tìm kiếm',
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: trendingSearches.map((keyword) {
              return ActionChip(
                avatar: const Icon(Icons.trending_up, size: 16),
                label: Text(keyword),
                onPressed: () => onSelect(keyword),
              );
            }).toList(),
          ),
        ],
  
        if (!isLoading &&
            savedSearches.isEmpty &&
            trendingSearches.isEmpty &&
            error == null)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(
              child: Text('Nhập từ khóa để bắt đầu tìm kiếm'),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'Không thể tải lịch sử tìm kiếm: $message',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}