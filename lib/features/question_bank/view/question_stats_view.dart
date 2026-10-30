import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/question_models.dart';
import '../../../data/repositories/question_bank_repository.dart';
import '../../../di/locator.dart';
import '../cubit/load_cubit.dart';
import '../widgets/qbank_widgets.dart';

/// Thống kê một câu hỏi: lượt làm, tỉ lệ đúng, phân bố phương án và đánh
/// giá, rồi danh sách nhận xét.
class QuestionStatsView extends StatelessWidget {
  final int questionId;

  /// Để tô xanh cột của đáp án đúng (rỗng nếu chưa biết).
  final List<String> correctKeys;

  const QuestionStatsView({
    super.key,
    required this.questionId,
    this.correctKeys = const [],
  });

  @override
  Widget build(BuildContext context) {
    final repo = getIt<QuestionBankRepository>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              LoadCubit<QuestionStatistics>(() => repo.statistics(questionId))
                ..load(),
        ),
        BlocProvider(
          create: (_) => PagedCubit<RatingItem>(
            (after) => repo.ratings(questionId, after: after),
          )..load(),
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        appBar: AppBar(title: const Text('Thống kê câu hỏi')),
        body: Builder(
          builder: (context) => PagedListView<RatingItem>(
            padding: EdgeInsets.zero,
            itemSpacing: 1,
            onRefresh: () async {
              await Future.wait([
                context.read<LoadCubit<QuestionStatistics>>().load(
                  silent: true,
                ),
                context.read<PagedCubit<RatingItem>>().refresh(),
              ]);
            },
            header: _StatsHeader(correctKeys: correctKeys),
            emptyView: const EmptyView(
              icon: AppIcons.comment,
              title: 'Chưa có nhận xét',
              compact: true,
            ),
            itemBuilder: (context, r) => _RatingTile(item: r),
          ),
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final List<String> correctKeys;
  const _StatsHeader({required this.correctKeys});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      LoadCubit<QuestionStatistics>,
      LoadState<QuestionStatistics>
    >(
      builder: (context, state) {
        final s = state.data;
        if (s == null) {
          return SizedBox(
            height: 220,
            child: state.status == LoadStatus.failure
                ? ErrorView(
                    error: state.error,
                    compact: true,
                    onRetry: context.read<LoadCubit<QuestionStatistics>>().load,
                  )
                : const LoadingView(),
          );
        }
        final optionTotal = s.optionDistribution.values.fold<int>(
          0,
          (a, b) => a + b,
        );
        final keys = s.optionDistribution.keys.toList()..sort();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QbankBlock(
              child: Row(
                children: [
                  _Metric(label: 'Lượt làm', value: '${s.totalAnswers}'),
                  _Metric(
                    label: 'Tỉ lệ đúng',
                    value: '${(s.correctRate * 100).round()}%',
                    color: AppColors.successDark,
                  ),
                  _Metric(
                    label: '${s.totalRatings} đánh giá',
                    value: s.totalRatings == 0
                        ? '-'
                        : s.avgRating.toStringAsFixed(1),
                    color: AppColors.secondary700,
                  ),
                ],
              ),
            ),
            const SectionGap(),
            QbankBlock(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const QbankSectionTitle('Phân bố lựa chọn'),
                  const SizedBox(height: 12),
                  if (keys.isEmpty)
                    const Text('Chưa có ai làm câu này.')
                  else
                    for (final k in keys)
                      _Bar(
                        label: k,
                        count: s.optionDistribution[k] ?? 0,
                        total: optionTotal,
                        color: correctKeys.contains(k)
                            ? AppColors.success
                            : AppColors.neutral400,
                      ),
                ],
              ),
            ),
            const SectionGap(),
            QbankBlock(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const QbankSectionTitle('Phân bố đánh giá'),
                  const SizedBox(height: 12),
                  for (final level in RatingLevel.values.reversed)
                    _Bar(
                      label: '${level.value}',
                      caption: level.label,
                      count: s.ratingDistribution[level.value] ?? 0,
                      total: s.totalRatings,
                      color: AppColors.secondary400,
                    ),
                ],
              ),
            ),
            const SectionGap(),
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: const QbankSectionTitle('Nhận xét'),
            ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một thanh ngang: nhãn, thanh tỉ lệ, số lượng.
class _Bar extends StatelessWidget {
  final String label;
  final String? caption;
  final int count;
  final int total;
  final Color color;

  const _Bar({
    required this.label,
    this.caption,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Đủ rộng cho nhãn dài nhất ("2 · Tác giả chưa vững"); chữ to thì
          // xuống dòng thay vì bị cắt.
          SizedBox(
            width: caption == null ? 24 : 172,
            child: Text(
              caption == null ? label : '$label · $caption',
              maxLines: 2,
              softWrap: true,
              style: theme.textTheme.labelLarge,
            ),
          ),
          if (caption != null) const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : count / total,
                minHeight: 10,
                color: color,
                backgroundColor: AppColors.chip,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  final RatingItem item;
  const _RatingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = item.level;
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: ComponentTokens.cardPadding,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Backend chỉ trả user_id, chưa có tên người đánh giá
              Text(
                'Người dùng #${item.userId}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              if (item.isError)
                const QbankChip(
                  label: 'Báo lỗi',
                  icon: AppIcons.flag,
                  color: AppColors.errorDark,
                  background: AppColors.errorLight,
                )
              else if (level != null)
                QbankChip(
                  label: '${level.value} · ${level.label}',
                  icon: AppIcons.points,
                  color: AppColors.secondary800,
                  background: AppColors.secondary100,
                ),
              const Spacer(),
              Text(
                TimeFormat.ago(item.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          if (item.comment != null && item.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.comment!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
