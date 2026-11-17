import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/game_models.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../di/locator.dart';
import '../widgets/game_widgets.dart';

/// Lịch sử các lượt dự đoán minigame của tôi (`GET /games/my-predictions`).
class MyPredictionsView extends StatelessWidget {
  const MyPredictionsView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PagedCubit<GamePrediction>(
      (after) => getIt<GameRepository>().myPredictions(after: after),
    )..load(),
    child: Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(title: const Text('Lịch sử dự đoán')),
      body: PagedListView<GamePrediction>(
        padding: EdgeInsets.zero,
        itemSpacing: ComponentTokens.postGap,
        emptyView: const EmptyView(
          icon: AppIcons.bolt,
          title: 'Bạn chưa tham gia minigame nào',
          message: 'Các lượt dự đoán và kết quả sẽ hiện ở đây.',
        ),
        itemBuilder: (context, p) => PredictionTile(prediction: p),
      ),
    ),
  );
}
