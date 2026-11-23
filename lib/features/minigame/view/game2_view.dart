import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/session_models.dart';
import '../../../data/repositories/submission_repository.dart';
import '../../../di/locator.dart';
import '../../question_bank/widgets/qbank_widgets.dart';
import '../widgets/game2_action.dart';

/// Minigame 2: chọn một phiên CỦA TÔI đang chờ duyệt rồi đoán số câu AI /
/// tự soạn sẽ được giảng viên duyệt.
class Game2View extends StatelessWidget {
  const Game2View({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    // Chỉ phiên còn chờ duyệt mới đặt cược được (đã xử lý thì biết kết quả)
    create: (_) => PagedCubit<SubmissionSummary>(
      (after) => getIt<SubmissionRepository>().mySubmissions(
        after: after,
        status: SessionStatus.pending,
      ),
    )..load(),
    child: const _Game2Body(),
  );
}

class _Game2Body extends StatelessWidget {
  const _Game2Body();

  Future<void> _open(BuildContext context, SubmissionSummary s) async {
    try {
      final d = await AppFeedback.withLoading(
        () => getIt<SubmissionRepository>().detail(s.sessionId),
      );
      if (!context.mounted) return;
      if (d.questions.isEmpty) {
        AppFeedback.info(context, 'Phiên này chưa có câu hỏi nào.');
        return;
      }
      await predictGame2(context, d);
    } on ApiException catch (e) {
      if (context.mounted) AppFeedback.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(title: const Text('Đoán số câu được duyệt')),
      body: PagedListView<SubmissionSummary>(
        padding: EdgeInsets.zero,
        itemSpacing: ComponentTokens.postGap,
        header: const QbankBlock(
          child: ExplanationBox(
            title: 'Luật chơi',
            text:
                'Chọn một phiên bạn đã đề xuất đang chờ duyệt, đoán CHÍNH XÁC '
                'số câu AI sinh và số câu tự soạn sẽ được giảng viên chọn vào '
                'ngân hàng đề. Mỗi phiên chỉ đoán một lần.',
            icon: AppIcons.info,
            color: AppColors.infoDark,
            background: AppColors.infoLight,
          ),
        ),
        emptyView: const EmptyView(
          icon: AppIcons.inbox,
          title: 'Không có phiên nào đang chờ duyệt',
          message: 'Đề xuất một phiên câu hỏi mới để chơi minigame này.',
          compact: true,
        ),
        itemBuilder: (context, s) => SessionTile(
          session: s,
          showStatus: false,
          onTap: () => _open(context, s),
        ),
      ),
    );
  }
}
