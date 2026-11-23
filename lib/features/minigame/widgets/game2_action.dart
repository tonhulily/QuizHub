import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/question_models.dart';
import '../../../data/models/session_models.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../di/locator.dart';
import '../../question_bank/widgets/qbank_widgets.dart';
import 'game_widgets.dart';

/// Số câu AI / tự soạn trong một phiên.
({int llm, int human}) sourceCounts(SubmissionDetail d) {
  final llm = d.questions.where((q) => q.source == QuestionSource.llm).length;
  return (llm: llm, human: d.questions.length - llm);
}

/// Game 2 chỉ mời chơi khi phiên còn chờ duyệt: giảng viên đã mở xem
/// (REVIEWING) thì kết quả có thể đã lộ dần, đã xử lý thì biết kết quả.
bool canPredictGame2(SessionStatus status) => status == SessionStatus.pending;

/// Minigame 2: hỏi số câu AI / tự soạn của phiên [d] sẽ được duyệt rồi gửi.
///
/// Loại câu nào phiên không có thì không hỏi (server trả 400 nếu cược loại
/// có 0 câu).
Future<GamePrediction?> predictGame2(
  BuildContext context,
  SubmissionDetail d,
) async {
  final counts = sourceCounts(d);
  if (counts.llm + counts.human == 0) return null;
  final fields = [
    if (counts.llm > 0)
      PredictionField(
        label: 'Số câu AI sinh được duyệt',
        helper: 'Phiên có ${counts.llm} câu do AI sinh',
        max: counts.llm,
      ),
    if (counts.human > 0)
      PredictionField(
        label: 'Số câu tự soạn được duyệt',
        helper: 'Phiên có ${counts.human} câu tự soạn',
        max: counts.human,
      ),
  ];
  final values = await showPredictionDialog(
    context,
    title: 'Minigame 2 · Đoán số câu được duyệt',
    message:
        'Đoán CHÍNH XÁC số câu của phiên "${d.title}" sẽ được giảng viên '
        'chọn vào ngân hàng đề để nhận điểm cộng.',
    fields: fields,
  );
  if (values == null || !context.mounted) return null;
  var i = 0;
  final llm = counts.llm > 0 ? values[i++] : null;
  final human = counts.human > 0 ? values[i] : null;
  return submitPrediction(
    context,
    () => getIt<GameRepository>().predictApprovedQuestions(
      sessionId: d.sessionId,
      llmCount: llm,
      humanCount: human,
    ),
  );
}

/// Khối mời chơi Minigame 2 trong màn chi tiết phiên của tôi.
class Game2Block extends StatefulWidget {
  final SubmissionDetail detail;
  const Game2Block({super.key, required this.detail});

  @override
  State<Game2Block> createState() => _Game2BlockState();
}

class _Game2BlockState extends State<Game2Block> {
  /// Lượt vừa đặt trong lần mở màn này (server không có API tra theo phiên;
  /// đặt lại sẽ nhận 409 "đã đặt cược").
  GamePrediction? _placed;

  Future<void> _play() async {
    final p = await predictGame2(context, widget.detail);
    if (p != null && mounted) setState(() => _placed = p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placed = _placed;
    return QbankBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(AppIcons.bolt, color: AppColors.secondary600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Minigame 2 · Đoán số câu được duyệt',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            placed == null
                ? 'Phiên đang chờ duyệt: đoán xem bao nhiêu câu AI sinh và '
                      'tự soạn sẽ được giảng viên chọn. Đoán đúng được cộng '
                      'điểm.'
                : 'Bạn đã đoán: ${placed.predictionText}. Kết quả có sau '
                      'khi giảng viên duyệt xong phiên.',
            style: theme.textTheme.bodyMedium,
          ),
          if (placed == null) ...[
            const SizedBox(height: 10),
            AppButton(
              label: 'Dự đoán ngay',
              icon: AppIcons.bolt,
              variant: AppButtonVariant.outline,
              small: true,
              onPressed: _play,
            ),
          ],
        ],
      ),
    );
  }
}
