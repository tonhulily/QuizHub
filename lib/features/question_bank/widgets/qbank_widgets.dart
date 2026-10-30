import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../data/models/auth_session.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/question_models.dart';
import '../../../data/models/session_models.dart';
import '../../../shared/post/post_media_grid.dart';

/// Nhãn nhỏ bo tròn (mã môn, trạng thái, nguồn câu hỏi...).
class QbankChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const QbankChip({
    super.key,
    required this.label,
    this.color = AppColors.textSecondary,
    this.background = AppColors.chip,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Nhãn trạng thái phiên. Trạng thái không rõ thì không hiện gì.
class SessionStatusChip extends StatelessWidget {
  final SessionStatus status;
  const SessionStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      SessionStatus.pending => (AppColors.warningDark, AppColors.warningLight),
      SessionStatus.reviewing => (AppColors.infoDark, AppColors.infoLight),
      SessionStatus.resolved => (AppColors.successDark, AppColors.successLight),
      SessionStatus.unknown => (AppColors.textSecondary, AppColors.chip),
    };
    if (status == SessionStatus.unknown) return const SizedBox.shrink();
    return QbankChip(label: status.label, color: fg, background: bg);
  }
}

/// Nhãn trạng thái duyệt của một câu hỏi.
class QuestionStatusChip extends StatelessWidget {
  final QuestionStatus status;
  const QuestionStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      QuestionStatus.pending => (AppColors.warningDark, AppColors.warningLight),
      QuestionStatus.approved => (
        AppColors.successDark,
        AppColors.successLight,
      ),
      QuestionStatus.rejected => (AppColors.errorDark, AppColors.errorLight),
      QuestionStatus.unknown => (AppColors.textSecondary, AppColors.chip),
    };
    if (status == QuestionStatus.unknown) return const SizedBox.shrink();
    return QbankChip(label: status.label, color: fg, background: bg);
  }
}

/// Nhãn "AI sinh" cho câu do LLM tạo; câu tự soạn không cần nhãn.
/// Nguồn câu hỏi (AI sinh / tự soạn) bị ẩn với giảng viên và người kiểm
/// duyệt, để việc chấm / duyệt không bị ảnh hưởng (yêu cầu "Bẫy Privacy").
bool showsQuestionSource(UserRole? role) =>
    role != UserRole.lecturer && role != UserRole.admin;

class SourceChip extends StatelessWidget {
  final QuestionSource source;
  const SourceChip({super.key, required this.source});

  @override
  Widget build(BuildContext context) => source == QuestionSource.llm
      ? QbankChip(
          label: source.label,
          icon: AppIcons.bolt,
          color: AppColors.secondary800,
          background: AppColors.secondary100,
        )
      : const SizedBox.shrink();
}

/// Một phiên trong danh sách: môn, tiêu đề, mô tả, số câu, thời gian.
class SessionTile extends StatelessWidget {
  final SubmissionSummary session;
  final VoidCallback? onTap;

  /// Ẩn nhãn trạng thái ở danh sách đã lọc sẵn theo trạng thái.
  final bool showStatus;

  const SessionTile({
    super.key,
    required this.session,
    this.onTap,
    this.showStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = session;
    final meta = [
      '${s.questionCount} câu hỏi',
      if (s.createdAt != null) TimeFormat.ago(s.createdAt),
    ].join(' · ');

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if ((s.subjectCode ?? s.subjectName) != null)
                    QbankChip(
                      label: s.subjectCode ?? s.subjectName!,
                      icon: AppIcons.subject,
                      color: AppColors.primary700,
                      background: AppColors.primary50,
                    ),
                  if (showStatus) SessionStatusChip(status: s.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                s.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (s.content != null && s.content!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  s.content!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const Icon(
                    AppIcons.chevronRight,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề nhỏ đầu mỗi khối.
class QbankSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const QbankSectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      ?trailing,
    ],
  );
}

/// Nội dung câu hỏi + ảnh minh hoạ (bấm ảnh để xem lớn).
class QuestionBody extends StatelessWidget {
  final String content;
  final List<String> imageUrls;

  const QuestionBody({
    super.key,
    required this.content,
    this.imageUrls = const [],
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        content,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      if (imageUrls.isNotEmpty) ...[
        const SizedBox(height: 12),
        PostMediaGrid(media: [for (final u in imageUrls) MediaItem(url: u)]),
      ],
    ],
  );
}

/// Cách tô một phương án.
enum OptionLook {
  /// Chưa nộp, chưa chọn
  idle,

  /// Chưa nộp, đang chọn
  selected,

  /// Đáp án đúng (đã nộp, hoặc xem phiên của mình)
  correct,

  /// Mình chọn nhưng sai
  wrong,

  /// Đã nộp, phương án không liên quan
  dimmed,
}

class OptionTile extends StatelessWidget {
  final QuestionOption option;
  final OptionLook look;
  final VoidCallback? onTap;

  const OptionTile({
    super.key,
    required this.option,
    this.look = OptionLook.idle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (border, bg, keyFg, keyBg) = switch (look) {
      OptionLook.idle => (
        AppColors.borderLight,
        AppColors.white,
        AppColors.textPrimary,
        AppColors.chip,
      ),
      OptionLook.selected => (
        AppColors.primary600,
        AppColors.primary50,
        AppColors.white,
        AppColors.primary600,
      ),
      OptionLook.correct => (
        AppColors.success,
        AppColors.successLight,
        AppColors.white,
        AppColors.success,
      ),
      OptionLook.wrong => (
        AppColors.error,
        AppColors.errorLight,
        AppColors.white,
        AppColors.error,
      ),
      OptionLook.dimmed => (
        AppColors.borderLight,
        AppColors.backgroundTertiary,
        AppColors.textTertiary,
        AppColors.chip,
      ),
    };
    final trailing = switch (look) {
      OptionLook.correct => AppIcons.success,
      OptionLook.wrong => AppIcons.error,
      _ => null,
    };

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        side: BorderSide(
          color: border,
          width: look == OptionLook.idle || look == OptionLook.dimmed ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: keyBg, shape: BoxShape.circle),
                child: Text(
                  option.key,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: keyFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: look == OptionLook.dimmed
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (option.mediaUrl != null) ...[
                      const SizedBox(height: 8),
                      PostMediaGrid(media: [MediaItem(url: option.mediaUrl!)]),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Icon(
                  trailing,
                  color: look == OptionLook.correct
                      ? AppColors.success
                      : AppColors.error,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Khung giải thích / lời giải sau khi trả lời.
class ExplanationBox extends StatelessWidget {
  final String title;
  final String text;
  final Color color;
  final Color background;
  final IconData icon;

  const ExplanationBox({
    super.key,
    required this.title,
    required this.text,
    this.color = AppColors.infoDark,
    this.background = AppColors.infoLight,
    this.icon = AppIcons.info,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(text, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Khối trắng có lề, dùng cho các phần của màn chi tiết.
class QbankBlock extends StatelessWidget {
  final Widget child;
  const QbankBlock({super.key, required this.child});

  @override
  Widget build(BuildContext context) => FlatSection(
    padding: const EdgeInsets.all(DesignTokens.spacingMD),
    child: child,
  );
}
