import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/search_models.dart';
import '../../../data/models/session_models.dart';
import '../../../data/models/subject_model.dart';
import '../../../shared/post/post_card.dart';
import '../../friends/widgets/person_card.dart';
import '../../question_bank/widgets/qbank_widgets.dart';
import '../../question_bank/widgets/question_social_bar.dart';

/// Một kết quả tìm kiếm toàn cục.
///
/// Ưu tiên widget dùng chung của từng feature để Search có cùng hành vi và
/// giao diện với các màn còn lại. Mỗi item chỉ render payload tương ứng với
/// [GlobalSearchItem.type], tránh trường hợp backend trả nhiều payload làm
/// một kết quả bị hiển thị lặp.
class SearchResultItem extends StatelessWidget {
  final GlobalSearchItem item;

  const SearchResultItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final content = switch (item.type) {
      SearchType.post when item.post != null => _PostContent(post: item.post!),
      SearchType.user when item.user != null => _UserContent(user: item.user!),
      SearchType.question when item.question != null => _QuestionContent(
        question: item.question!,
      ),
      SearchType.session when item.session != null => _SessionContent(
        session: item.session!,
      ),
      SearchType.subject when item.subject != null => _SubjectContent(
        subject: item.subject!,
      ),
      _ => _fallbackContent(),
    };

    // PostCard tự quản lý khối trắng và spacing theo chuẩn feed.
    if (item.type == SearchType.post && item.post != null) return content;

    return FlatSection(
      padding: const EdgeInsets.all(DesignTokens.spacingMD),
      child: content,
    );
  }

  Widget _fallbackContent() => Builder(
    builder: (context) => Text(
      'Không có thông tin hiển thị cho kết quả này.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

class _PostContent extends StatelessWidget {
  final SearchPost post;

  const _PostContent({required this.post});

  @override
  Widget build(BuildContext context) {
    // Search API trả media_urls dạng List<String>, trong khi PostCard dùng
    // PostModel với List<MediaItem>. Dữ liệu chưa có type nên mặc định ảnh.
    final model = PostModel(
      postId: post.postId,
      content: post.content,
      postType: PostType.parse(post.postType),
      author: post.author,
      media: [for (final url in post.mediaUrls) MediaItem(url: url)],
      reactCount: post.reactCount,
      commentCount: post.commentCount,
      createdAt: post.createdAt,
    );

    return PostCard(
      post: model,
      onTap: (p) => Navigator.of(
        context,
      ).pushNamed(AppRoutes.postDetail, arguments: p.postId),
    );
  }
}

class _UserContent extends StatelessWidget {
  final SearchUser user;

  const _UserContent({required this.user});

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildSubtitle(user);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ResultTypeLabel(icon: AppIcons.person, label: 'Người dùng'),
        const SizedBox(height: 8),
        PersonCard(
          key: ValueKey('global_search_user_${user.userId}'),
          name: user.fullName,
          subtitle: subtitle,
          avatarUrl: user.avatarUrl,
          frameUrl: user.frameUrl,
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.userProfile,
            arguments: user.userId,
          ),
          trailing: const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Icon(
              AppIcons.chevronRight,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        if (user.bio?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            user.bio!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '${user.followersCount} người theo dõi'
          ' • ${user.totalProposedQuestions} câu hỏi đóng góp',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String? _buildSubtitle(SearchUser user) {
    final parts = <String>[
      if (user.studentLecturerCode?.isNotEmpty == true)
        user.studentLecturerCode!,
      if (user.schoolFaculty?.isNotEmpty == true) user.schoolFaculty!,
      if (user.major?.isNotEmpty == true) user.major!,
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }
}

class _QuestionContent extends StatelessWidget {
  final SearchQuestion question;

  const _QuestionContent({required this.question});

  void _openQuestion(BuildContext context) {
    final sessionId = question.sessionId;
    if (sessionId == null || sessionId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Câu hỏi này chưa có thông tin phiên để mở luyện tập.'),
        ),
      );
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.qbankPractice,
      arguments: (sessionId: sessionId, questionId: question.questionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = question;
    return InkWell(
      onTap: () => _openQuestion(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ResultTypeLabel(icon: AppIcons.quiz, label: 'Câu hỏi'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (q.questionCode?.isNotEmpty == true)
                QbankChip(label: q.questionCode!),
              if (q.subjectName?.isNotEmpty == true)
                QbankChip(
                  label: q.subjectName!,
                  icon: AppIcons.subject,
                  color: AppColors.primary700,
                  background: AppColors.primary50,
                ),
              QbankChip(label: q.difficulty.label),
            ],
          ),
          const SizedBox(height: 10),
          QuestionBody(content: q.content, imageUrls: q.imageUrls),
          if (q.topicName?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              'Chủ đề: ${q.topicName}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            q.sessionId != null && q.sessionId! > 0
                ? 'Nhấn nội dung để mở câu hỏi trong phiên luyện tập'
                : 'Chưa có thông tin phiên để mở câu hỏi luyện tập',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.primary600),
          ),
          QuestionSocialBar(
            questionId: q.questionId,
            reactCount: q.reactCount,
            commentCount: q.commentCount,
          ),
        ],
      ),
    );
  }
}

class _SessionContent extends StatelessWidget {
  final SearchSession session;

  const _SessionContent({required this.session});

  @override
  Widget build(BuildContext context) {
    final status = SessionStatus.parse(session.status);
    final summary = SubmissionSummary(
      sessionId: session.sessionId,
      title: session.title,
      content: session.content,
      subjectId: session.subjectId,
      subjectName: session.subjectName,
      questionCount: session.questionCount,
      status: status,
      createdAt: session.createdAt,
      reactCount: session.reactCount,
      commentCount: session.commentCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ResultTypeLabel(icon: AppIcons.friends, label: 'Phiên đóng góp'),
        const SizedBox(height: 8),
        SessionTile(
          session: summary,
          onTap: () {
            if (status == SessionStatus.resolved) {
              Navigator.of(context).pushNamed(
                AppRoutes.qbankPractice,
                arguments: session.sessionId,
              );
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Phiên này chưa được duyệt nên chưa thể luyện tập.',
                ),
              ),
            );
          },
        ),
        if (session.reactCount > 0 || session.commentCount > 0) ...[
          const SizedBox(height: 8),
          _EngagementInfo(
            firstIcon: AppIcons.like,
            firstCount: session.reactCount,
            secondIcon: AppIcons.comment,
            secondCount: session.commentCount,
          ),
        ],
      ],
    );
  }
}

class _SubjectContent extends StatelessWidget {
  final SubjectModel subject;

  const _SubjectContent({required this.subject});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => Navigator.of(
      context,
    ).pushNamed(AppRoutes.searchGlobal, arguments: subject.code),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ResultTypeLabel(icon: AppIcons.subject, label: 'Môn học'),
          const SizedBox(height: 8),
          Text(
            subject.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subject.code.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subject.code,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Tìm câu hỏi thuộc môn học này',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.primary600),
          ),
        ],
      ),
    ),
  );
}

class _ResultTypeLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ResultTypeLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 6),
      Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _EngagementInfo extends StatelessWidget {
  final IconData firstIcon;
  final int firstCount;
  final IconData secondIcon;
  final int secondCount;

  const _EngagementInfo({
    required this.firstIcon,
    required this.firstCount,
    required this.secondIcon,
    required this.secondCount,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(firstIcon, size: 17, color: AppColors.textTertiary),
      const SizedBox(width: 4),
      Text('$firstCount', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(width: 16),
      Icon(secondIcon, size: 17, color: AppColors.textTertiary),
      const SizedBox(width: 4),
      Text('$secondCount', style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
