import 'package:flutter/material.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../friends/widgets/person_card.dart';

import '../../../data/models/search_models.dart';

class SearchResultItem extends StatelessWidget {
  final GlobalSearchItem item;

  const SearchResultItem({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (item.post != null) {
      children.add(_PostContent(post: item.post!));
    }

    if (item.user != null) {
      children.add(_UserContent(user: item.user!));
    }

    if (item.question != null) {
      children.add(_QuestionContent(question: item.question!));
    }

    if (item.session != null) {
      children.add(_SessionContent(session: item.session!));
    }

    if (item.subject != null) {
      children.add(_SubjectContent(subject: item.subject!));
    }

    if (children.isEmpty) {
      children.add(
        Text(
          'Không có thông tin hiển thị cho kết quả này.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return FlatSection(
      padding: const EdgeInsets.all(DesignTokens.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _joinWithDivider(children),
      ),
    );
  }

  List<Widget> _joinWithDivider(List<Widget> children) {
    final result = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        result.add(const Divider(height: 24));
      }

      result.add(children[i]);
    }

    return result;
  }
}

class _PostContent extends StatelessWidget {
  final SearchPost post;

  const _PostContent({required this.post});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ResultTypeLabel(
          icon: Icons.article_outlined,
          label: 'Bài viết',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            UserAvatar(
              avatarUrl: post.author.avatarUrl,
              frameUrl: post.author.frameUrl,
              name: post.author.fullName,
              size: 40,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.author.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (post.createdAt != null)
                    Text(
                      _formatDate(post.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(post.content),
        if (post.mediaUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          _MediaPreview(urls: post.mediaUrls),
        ],
        const SizedBox(height: 10),
        _EngagementInfo(
          firstIcon: Icons.favorite_border,
          firstCount: post.reactCount,
          secondIcon: Icons.chat_bubble_outline,
          secondCount: post.commentCount,
        ),
      ],
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
        const _ResultTypeLabel(
          icon: Icons.person_outline,
          label: 'Người dùng',
        ),
        const SizedBox(height: 8),
        PersonCard(
          key: ValueKey('global_search_user_${user.userId}'),
          name: user.fullName,
          subtitle: subtitle,
          avatarUrl: user.avatarUrl,
          frameUrl: user.frameUrl,
          onTap: () => _openProfile(context),
          trailing: const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Icon(
              AppIcons.chevronRight,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        if (user.bio != null && user.bio!.isNotEmpty) ...[
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
    final parts = <String>[];

    if (user.studentLecturerCode?.isNotEmpty == true) {
      parts.add(user.studentLecturerCode!);
    }

    if (user.schoolFaculty?.isNotEmpty == true) {
      parts.add(user.schoolFaculty!);
    }

    if (user.major?.isNotEmpty == true) {
      parts.add(user.major!);
    }

    return parts.isEmpty ? null : parts.join(' • ');
  }

  void _openProfile(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.userProfile,
      arguments: user.userId,
    );
  }
}

class _QuestionContent extends StatelessWidget {
  final SearchQuestion question;

  const _QuestionContent({required this.question});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ResultTypeLabel(
          icon: Icons.quiz_outlined,
          label: 'Câu hỏi',
        ),
        const SizedBox(height: 8),
        if (question.questionCode != null)
          Text(
            question.questionCode!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        Text(
          question.content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (question.subjectName != null)
              _InfoChip(
                icon: Icons.menu_book_outlined,
                label: question.subjectName!,
              ),
            if (question.topicName != null)
              _InfoChip(
                icon: Icons.topic_outlined,
                label: question.topicName!,
              ),
            _InfoChip(
              icon: Icons.signal_cellular_alt,
              label: _enumLabel(question.difficulty),
            ),
          ],
        ),
        if (question.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          _MediaPreview(urls: question.imageUrls),
        ],
        const SizedBox(height: 10),
        _EngagementInfo(
          firstIcon: Icons.favorite_border,
          firstCount: question.reactCount,
          secondIcon: Icons.chat_bubble_outline,
          secondCount: question.commentCount,
        ),
      ],
    );
  }
}

class _SessionContent extends StatelessWidget {
  final SearchSession session;

  const _SessionContent({required this.session});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ResultTypeLabel(
          icon: Icons.groups_outlined,
          label: 'Phiên đóng góp',
        ),
        const SizedBox(height: 8),
        Text(
          session.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (session.content != null) ...[
          const SizedBox(height: 4),
          Text(
            session.content!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (session.subjectName != null)
              _InfoChip(
                icon: Icons.menu_book_outlined,
                label: session.subjectName!,
              ),
            _InfoChip(
              icon: Icons.quiz_outlined,
              label: '${session.questionCount} câu hỏi',
            ),
            if (session.status != null)
              _InfoChip(
                icon: Icons.info_outline,
                label: session.status!,
              ),
          ],
        ),
        const SizedBox(height: 8),
        _EngagementInfo(
          firstIcon: Icons.favorite_border,
          firstCount: session.reactCount,
          secondIcon: Icons.chat_bubble_outline,
          secondCount: session.commentCount,
        ),
      ],
    );
  }
}

class _SubjectContent extends StatelessWidget {
  final dynamic subject;

  const _SubjectContent({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ResultTypeLabel(
          icon: Icons.menu_book_outlined,
          label: 'Học phần',
        ),
        const SizedBox(height: 8),
        Text(
          subject.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (subject.code.isNotEmpty)
          Text(
            subject.code,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _ResultTypeLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ResultTypeLabel({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
}


class _MediaPreview extends StatelessWidget {
  final List<String> urls;

  const _MediaPreview({required this.urls});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length > 4 ? 4 : urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              urls[index],
              width: 110,
              height: 110,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 110,
                height: 110,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          );
        },
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;

    return Row(
      children: [
        Icon(firstIcon, size: 17, color: Theme.of(context).hintColor),
        const SizedBox(width: 4),
        Text('$firstCount', style: style),
        const SizedBox(width: 16),
        Icon(secondIcon, size: 17, color: Theme.of(context).hintColor),
        const SizedBox(width: 4),
        Text('$secondCount', style: style),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 15),
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelSmall,
      padding: EdgeInsets.zero,
    );
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year}';
}

String _enumLabel(Object value) {
  return value.toString().split('.').last;
}