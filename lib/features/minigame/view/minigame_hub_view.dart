import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../data/models/game_models.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../di/locator.dart';
import '../../question_bank/cubit/load_cubit.dart';
import '../widgets/game_widgets.dart';
import 'leaderboard_view.dart';

/// Màn "Minigame": thứ hạng của tôi + các minigame dự đoán backend hỗ trợ
/// (Game 1, 2, 4 - Swagger mục 21) + lịch sử dự đoán.
class MinigameHubView extends StatelessWidget {
  const MinigameHubView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        LoadCubit<Leaderboard>(() => getIt<GameRepository>().leaderboard())
          ..load(),
    child: const _HubBody(),
  );
}

class _HubBody extends StatelessWidget {
  const _HubBody();

  void _go(BuildContext context, String route) =>
      Navigator.of(context).pushNamed(route);

  @override
  Widget build(BuildContext context) {
    final rankCubit = context.read<LoadCubit<Leaderboard>>();
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('Minigame'),
        actions: [
          IconButton(
            tooltip: 'Lịch sử dự đoán',
            icon: const Icon(AppIcons.joined),
            onPressed: () => _go(context, AppRoutes.minigamePredictions),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => rankCubit.load(silent: true),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 12),
            // Thứ hạng chỉ là phần phụ: lỗi thì ẩn, không chặn cả màn
            BlocBuilder<LoadCubit<Leaderboard>, LoadState<Leaderboard>>(
              builder: (context, state) {
                final me = state.data?.myRank;
                if (me == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MyRankCard(
                    rank: me,
                    onTap: () => _go(context, AppRoutes.leaderboard),
                  ),
                );
              },
            ),
            GameCard(
              number: 1,
              title: 'Đoán số người đề xuất',
              description:
                  'Ngày mai lớp bạn sẽ có bao nhiêu người đề xuất câu hỏi? '
                  'Chốt trước 22:00, sai số ±5%.',
              reward: 'Điểm thưởng khi đoán trúng',
              icon: AppIcons.classGroup,
              color: AppColors.primary600,
              actionLabel: 'Chơi',
              onTap: () => _go(context, AppRoutes.minigameParticipants),
            ),
            const SectionGap(),
            GameCard(
              number: 2,
              title: 'Đoán số câu được duyệt',
              description:
                  'Đoán chính xác số câu AI sinh và tự soạn trong phiên của '
                  'bạn sẽ được giảng viên chọn.',
              reward: 'Điểm cộng khi đoán chính xác',
              icon: AppIcons.shieldCheck,
              color: AppColors.secondary600,
              actionLabel: 'Chọn phiên',
              onTap: () => _go(context, AppRoutes.minigameApprovedQuestions),
            ),
            const SectionGap(),
            GameCard(
              number: 4,
              title: 'Đoán quy mô ngân hàng đề',
              description:
                  'Cuối kỳ, ngân hàng đề của môn sẽ có bao nhiêu câu? Mỗi '
                  'người chỉ đoán một lần.',
              reward: 'Top 3 sát nhất & sớm nhất',
              icon: AppIcons.subject,
              color: AppColors.infoDark,
              actionLabel: 'Chơi',
              onTap: () => _go(context, AppRoutes.minigameBankSize),
            ),
            const SectionGap(),
            FlatSection(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      AppIcons.leaderboard,
                      color: AppColors.secondary600,
                    ),
                    title: const Text('Bảng xếp hạng'),
                    trailing: const Icon(AppIcons.chevronRight, size: 16),
                    onTap: () => _go(context, AppRoutes.leaderboard),
                  ),
                  ListTile(
                    leading: const Icon(
                      AppIcons.joined,
                      color: AppColors.primary600,
                    ),
                    title: const Text('Lịch sử dự đoán'),
                    trailing: const Icon(AppIcons.chevronRight, size: 16),
                    onTap: () => _go(context, AppRoutes.minigamePredictions),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
