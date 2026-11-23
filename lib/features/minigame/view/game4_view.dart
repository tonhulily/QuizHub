import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../data/repositories/subject_repository.dart';
import '../../../di/locator.dart';
import '../../question_bank/cubit/load_cubit.dart';
import '../../question_bank/widgets/qbank_widgets.dart';
import '../widgets/game_widgets.dart';

/// Môn đang học + lượt đoán Game 4 đã đặt (theo `subject_id`).
typedef Game4Data = ({
  List<SubjectModel> subjects,
  Map<int, GamePrediction> placed,
});

/// Minigame 4: đoán tổng số câu được duyệt vào ngân hàng đề của môn khi kết
/// thúc học kỳ. Mỗi môn đoán MỘT lần; top 3 sát nhất và sớm nhất có thưởng.
class Game4View extends StatelessWidget {
  const Game4View({super.key});

  /// Backend không có API "đã cược môn này chưa": suy ra từ lịch sử dự đoán
  /// (trang đầu, tối đa 50 lượt gần nhất là đủ cho số môn một kỳ).
  static Future<Game4Data> _load() async {
    final subjectsF = getIt<SubjectRepository>().enrolled(
      currentSemester: true,
    );
    final historyF = getIt<GameRepository>().myPredictions(limit: 50);
    // Future.wait ném lại nguyên ApiException đầu tiên (LoadCubit bắt được)
    // và tự xử lý lỗi của future còn lại.
    await Future.wait([subjectsF, historyF]);
    final subjects = await subjectsF;
    final history = await historyF;
    return (
      subjects: subjects,
      placed: {
        for (final p in history.items.reversed)
          if (p.gameType == GameType.bankSize && p.targetId != null)
            p.targetId!: p,
      },
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LoadCubit<Game4Data>(_load)..load(),
    child: const _Game4Body(),
  );
}

class _Game4Body extends StatelessWidget {
  const _Game4Body();

  Future<void> _predict(BuildContext context, SubjectModel s) async {
    final cubit = context.read<LoadCubit<Game4Data>>();
    final values = await showPredictionDialog(
      context,
      title: s.label,
      message:
          'Hết học kỳ, ngân hàng đề của môn này sẽ có tổng cộng bao nhiêu '
          'câu hỏi được duyệt? Chỉ 3 người đoán sát nhất và sớm nhất nhận '
          'thưởng.',
      fields: const [PredictionField(label: 'Tổng số câu hỏi')],
    );
    if (values == null || !context.mounted) return;
    final p = await submitPrediction(
      context,
      () => getIt<GameRepository>().predictBankSize(
        subjectId: s.subjectId,
        predictedBankSize: values.first,
      ),
    );
    if (p != null) cubit.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoadCubit<Game4Data>>();
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(title: const Text('Đoán quy mô ngân hàng đề')),
      body: BlocBuilder<LoadCubit<Game4Data>, LoadState<Game4Data>>(
        builder: (context, state) => switch (state.status) {
          LoadStatus.loading => const LoadingView(),
          LoadStatus.failure => ErrorView(
            error: state.error,
            onRetry: cubit.load,
          ),
          LoadStatus.loaded => RefreshIndicator(
            onRefresh: () => cubit.load(silent: true),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const QbankBlock(
                  child: ExplanationBox(
                    title: 'Luật chơi',
                    text:
                        'Mỗi môn chỉ được đoán MỘT lần trong học kỳ. Khi chốt '
                        'sổ cuối kỳ, 3 người đoán gần đúng nhất (ưu tiên '
                        'người đoán sớm hơn) được cộng điểm.',
                    icon: AppIcons.info,
                    color: AppColors.infoDark,
                    background: AppColors.infoLight,
                  ),
                ),
                if (state.data!.subjects.isEmpty)
                  const EmptyView(
                    icon: AppIcons.subject,
                    title: 'Bạn chưa đăng ký môn học nào',
                    compact: true,
                  ),
                for (final s in state.data!.subjects) ...[
                  const SectionGap(),
                  _SubjectTile(
                    subject: s,
                    placed: state.data!.placed[s.subjectId],
                    onPredict: () => _predict(context, s),
                  ),
                ],
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final SubjectModel subject;
  final GamePrediction? placed;
  final VoidCallback onPredict;

  const _SubjectTile({
    required this.subject,
    required this.placed,
    required this.onPredict,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = placed;
    return QbankBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            subject.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subject.code.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subject.code,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (p != null)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Bạn đoán: ${p.predictionText}'),
                PredictionResultChip(prediction: p),
              ],
            )
          else
            AppButton(
              label: 'Dự đoán',
              icon: AppIcons.bolt,
              small: true,
              onPressed: onPredict,
            ),
        ],
      ),
    );
  }
}
