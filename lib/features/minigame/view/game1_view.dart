import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/game_models.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../di/locator.dart';
import '../../question_bank/cubit/load_cubit.dart';
import '../../question_bank/widgets/qbank_widgets.dart';
import '../widgets/game_widgets.dart';

/// Minigame 1: đoán số sinh viên của lớp sẽ đề xuất câu hỏi vào ngày mai.
class Game1View extends StatelessWidget {
  const Game1View({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        LoadCubit<List<Game1Class>>(getIt<GameRepository>().game1Classes)
          ..load(),
    child: const _Game1Body(),
  );
}

class _Game1Body extends StatelessWidget {
  const _Game1Body();

  Future<void> _predict(BuildContext context, Game1Class c) async {
    final cubit = context.read<LoadCubit<List<Game1Class>>>();
    final values = await showPredictionDialog(
      context,
      title: 'Lớp ${c.classCode}',
      message:
          'Ngày mai sẽ có bao nhiêu sinh viên lớp này đề xuất câu hỏi? '
          'Sai số trong khoảng ±5% vẫn tính là trúng.',
      fields: const [PredictionField(label: 'Số sinh viên', min: 1)],
    );
    if (values == null || !context.mounted) return;
    final p = await submitPrediction(
      context,
      () => getIt<GameRepository>().predictParticipants(
        courseClassId: c.courseClassId,
        predictedCount: values.first,
      ),
    );
    if (p != null) cubit.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoadCubit<List<Game1Class>>>();
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(title: const Text('Đoán số người đề xuất')),
      body: BlocBuilder<LoadCubit<List<Game1Class>>, LoadState<List<Game1Class>>>(
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
                        'Mỗi lớp được đoán MỘT lần cho ngày mai, chốt trước '
                        '22:00 hằng ngày. Đoán lệch không quá 5% so với số '
                        'người thực tế đề xuất câu hỏi để nhận điểm thưởng.',
                    icon: AppIcons.info,
                    color: AppColors.infoDark,
                    background: AppColors.infoLight,
                  ),
                ),
                if (state.data!.isEmpty)
                  const EmptyView(
                    icon: AppIcons.classGroup,
                    title: 'Bạn chưa tham gia lớp học phần nào',
                    message: 'Khi được thêm vào lớp, lớp sẽ hiện ở đây.',
                    compact: true,
                  ),
                for (final c in state.data!) ...[
                  const SectionGap(),
                  _ClassTile(cls: c, onPredict: () => _predict(context, c)),
                ],
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  final Game1Class cls;
  final VoidCallback onPredict;

  const _ClassTile({required this.cls, required this.onPredict});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = cls;
    return QbankBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            c.subjectName ?? 'Lớp học phần',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              'Mã lớp ${c.classCode}',
              if (c.semester != null) 'Kỳ ${c.semester}',
              if (c.lecturerName != null) c.lecturerName!,
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (c.alreadyPredicted)
            Align(
              alignment: Alignment.centerLeft,
              child: QbankChip(
                label: c.predictedCount == null
                    ? 'Đã đoán cho ngày mai'
                    : 'Đã đoán ${c.predictedCount} người cho ngày mai',
                icon: AppIcons.success,
                color: AppColors.successDark,
                background: AppColors.successLight,
              ),
            )
          else
            AppButton(
              label: 'Dự đoán cho ngày mai',
              icon: AppIcons.bolt,
              small: true,
              onPressed: onPredict,
            ),
        ],
      ),
    );
  }
}
