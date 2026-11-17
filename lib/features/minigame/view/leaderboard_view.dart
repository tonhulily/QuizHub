import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../data/repositories/subject_repository.dart';
import '../../../di/locator.dart';
import '../../question_bank/cubit/load_cubit.dart';
import '../../question_bank/widgets/qbank_widgets.dart';

/// Bảng xếp hạng vinh danh (`GET /games/leaderboard`): cả học kỳ hoặc theo
/// từng môn đang học.
class LeaderboardView extends StatefulWidget {
  const LeaderboardView({super.key});

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  LeaderboardPeriod _period = LeaderboardPeriod.semester;
  SubjectModel? _subject;

  late final LoadCubit<Leaderboard> _board = LoadCubit(
    () => getIt<GameRepository>().leaderboard(
      period: _period,
      subjectId: _subject?.subjectId,
    ),
  )..load();

  late final LoadCubit<List<SubjectModel>> _subjects = LoadCubit(
    () => getIt<SubjectRepository>().enrolled(),
  )..load();

  @override
  void dispose() {
    _board.close();
    _subjects.close();
    super.dispose();
  }

  void _setPeriod(LeaderboardPeriod p) {
    if (p == _period) return;
    setState(() {
      _period = p;
      // Xếp hạng theo môn bắt buộc có subject_id: mặc định môn đầu tiên
      if (p == LeaderboardPeriod.subject && _subject == null) {
        _subject = _subjects.state.data?.firstOrNull;
      }
    });
    if (p == LeaderboardPeriod.subject && _subject == null) return;
    _board.load();
  }

  void _setSubject(SubjectModel s) {
    if (s == _subject) return;
    setState(() => _subject = s);
    _board.load();
  }

  @override
  Widget build(BuildContext context) {
    final bySubject = _period == LeaderboardPeriod.subject;
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(title: const Text('Bảng xếp hạng')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<LeaderboardPeriod>(
                  showSelectedIcon: false,
                  segments: [
                    for (final p in LeaderboardPeriod.values)
                      ButtonSegment(value: p, label: Text(p.label)),
                  ],
                  selected: {_period},
                  onSelectionChanged: (v) => _setPeriod(v.first),
                ),
                if (bySubject)
                  BlocBuilder<
                    LoadCubit<List<SubjectModel>>,
                    LoadState<List<SubjectModel>>
                  >(
                    bloc: _subjects,
                    builder: (context, state) {
                      final list = state.data ?? const <SubjectModel>[];
                      if (list.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final s in list)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      s.code.isEmpty ? s.name : s.code,
                                    ),
                                    tooltip: s.name,
                                    showCheckmark: false,
                                    selected: s == _subject,
                                    onSelected: (_) => _setSubject(s),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: bySubject && _subject == null
                ? const EmptyView(
                    icon: AppIcons.subject,
                    title: 'Chọn một môn học',
                    message: 'Bạn cần đăng ký môn để xem xếp hạng theo môn.',
                  )
                : BlocBuilder<LoadCubit<Leaderboard>, LoadState<Leaderboard>>(
                    bloc: _board,
                    builder: (context, state) => switch (state.status) {
                      LoadStatus.loading => const LoadingView(),
                      LoadStatus.failure => ErrorView(
                        error: state.error,
                        onRetry: _board.load,
                      ),
                      LoadStatus.loaded => RefreshIndicator(
                        onRefresh: () => _board.load(silent: true),
                        child: _BoardList(board: state.data!),
                      ),
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BoardList extends StatelessWidget {
  final Leaderboard board;
  const _BoardList({required this.board});

  @override
  Widget build(BuildContext context) {
    final me = board.myRank;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (me != null) ...[const SizedBox(height: 8), MyRankCard(rank: me)],
        const SectionGap(),
        if (board.entries.isEmpty)
          const EmptyView(
            icon: AppIcons.leaderboard,
            title: 'Chưa có ai trên bảng xếp hạng',
            message: 'Tham gia đề xuất câu hỏi và minigame để tích điểm.',
            compact: true,
          )
        else
          FlatSection(
            padding: EdgeInsets.zero,
            child: Column(
              children: [for (final e in board.entries) _EntryTile(entry: e)],
            ),
          ),
      ],
    );
  }
}

/// Thẻ thứ hạng của tôi (dùng chung với màn Minigame).
class MyRankCard extends StatelessWidget {
  final MyRank rank;
  final VoidCallback? onTap;
  const MyRankCard({super.key, required this.rank, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = rank;
    final onBrand = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.white70,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: AppColors.brandGradient),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  UserAvatar(
                    avatarUrl: r.avatarUrl,
                    frameUrl: r.frameUrl,
                    name: r.fullName,
                    size: 52,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thứ hạng của bạn', style: onBrand),
                        const SizedBox(height: 2),
                        Text(
                          r.ranked ? '#${r.rank}' : 'Chưa xếp hạng',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (r.ranked && r.topPercent != null)
                          Text(
                            'Top ${formatPoints(r.topPercent!)}% · '
                            '${r.totalParticipants} người',
                            style: onBrand,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatPoints(r.totalPoints),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('điểm', style: onBrand),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final LeaderboardEntry entry;
  const _EntryTile({required this.entry});

  static const _medals = [
    AppColors.goldGradientStart,
    AppColors.neutral400,
    AppColors.warningDark,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;
    final medal = e.rank >= 1 && e.rank <= 3 ? _medals[e.rank - 1] : null;
    return Container(
      color: e.isCurrentUser ? AppColors.primary50 : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: medal != null
                ? Icon(AppIcons.trophy, color: medal, size: 24)
                : Text(
                    '${e.rank}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          UserAvatar(
            avatarUrl: e.avatarUrl,
            frameUrl: e.frameUrl,
            name: e.fullName,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.isCurrentUser ? '${e.fullName} (bạn)' : e.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (e.userCode != null)
                  Text(
                    e.userCode!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          QbankChip(
            label: formatPoints(e.totalPoints),
            icon: AppIcons.points,
            color: AppColors.warningDark,
            background: AppColors.warningLight,
          ),
        ],
      ),
    );
  }
}
