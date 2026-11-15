import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/media/media_viewer.dart';
import 'chat_tokens.dart';

/// Các tin cùng người gửi nối thành một cụm, avatar đặt ở cuối cụm.
class ChatMessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool joinsOlder;
  final bool joinsNewer;
  final String? avatarUrl;
  final Iterable<int> userIds;
  final VoidCallback onLongPress;
  final String? receipt;

  const ChatMessageTile({
    super.key,
    required this.message,
    required this.mine,
    required this.onLongPress,
    this.joinsOlder = false,
    this.joinsNewer = false,
    this.avatarUrl,
    this.userIds = const [],
    this.receipt,
  });

  Future<void> _open(BuildContext context, String url) async {
    if (['IMAGE', 'VIDEO', 'GIF'].contains(message.messageType)) {
      await MediaViewer.open(
        context,
        [
          MediaItem(
            url: url,
            type: message.messageType == 'VIDEO'
                ? MediaType.video
                : MediaType.image,
          ),
        ],
        userIds: {...userIds, message.senderId},
      );
    } else {
      final uri = Uri.tryParse(url);
      final opened =
          uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        AppFeedback.errorMessage(context, 'Không mở được tệp đính kèm.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final round = Radius.circular(ChatTokens.bubbleRadius);
    final joined = Radius.circular(ChatTokens.joinedRadius);
    final radius = BorderRadius.only(
      topLeft: !mine && joinsOlder ? joined : round,
      bottomLeft: !mine && joinsNewer ? joined : round,
      topRight: mine && joinsOlder ? joined : round,
      bottomRight: mine && joinsNewer ? joined : round,
    );
    final hasImage =
        !message.revoked &&
        message.mediaUrls.isNotEmpty &&
        ['IMAGE', 'GIF', 'VIDEO'].contains(message.messageType);
    final color = mine && !message.revoked
        ? AppColors.white
        : AppColors.textPrimary;
    return Padding(
      padding: EdgeInsets.only(
        bottom: joinsNewer ? ChatTokens.groupedGap : ChatTokens.groupGap,
      ),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[
                SizedBox(
                  width: ChatTokens.messageAvatar,
                  child: joinsNewer
                      ? null
                      : UserAvatar(
                          name: message.senderName,
                          avatarUrl: message.avatarUrl ?? avatarUrl,
                          size: ChatTokens.messageAvatar,
                        ),
                ),
                const SizedBox(width: ChatTokens.avatarGap),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        MediaQuery.sizeOf(context).width *
                        ChatTokens.bubbleWidthFactor,
                  ),
                  child: Tooltip(
                    message: message.createdAt == null
                        ? ''
                        : MaterialLocalizations.of(context).formatTimeOfDay(
                            TimeOfDay.fromDateTime(
                              message.createdAt!.toLocal(),
                            ),
                            alwaysUse24HourFormat: true,
                          ),
                    child: GestureDetector(
                      onLongPress: onLongPress,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: message.revoked
                              ? AppColors.white
                              : mine
                              ? AppColors.primary600
                              : AppColors.backgroundSecondary,
                          borderRadius: radius,
                          border: message.revoked
                              ? Border.all(color: AppColors.borderLight)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasImage)
                              for (final url in message.mediaUrls)
                                Semantics(
                                  button: true,
                                  label: message.messageType == 'VIDEO'
                                      ? 'Xem video'
                                      : 'Xem ảnh',
                                  child: InkWell(
                                    onTap: () => _open(context, url),
                                    child: SizedBox(
                                      width: ChatTokens.mediaWidth,
                                      height: ChatTokens.mediaWidth * .75,
                                      child: message.messageType == 'VIDEO'
                                          ? const ColoredBox(
                                              color: AppColors.neutral800,
                                              child: Center(
                                                child: Icon(
                                                  AppIcons.playCircle,
                                                  color: AppColors.white,
                                                  size: ChatTokens.headerAvatar,
                                                ),
                                              ),
                                            )
                                          : CachedNetworkImage(
                                              imageUrl: url,
                                              fit: BoxFit.cover,
                                              placeholder: (_, _) =>
                                                  const ColoredBox(
                                                    color: AppColors.chip,
                                                  ),
                                              errorWidget: (_, _, _) =>
                                                  const ColoredBox(
                                                    color: AppColors.chip,
                                                    child: Center(
                                                      child: Icon(
                                                        AppIcons.imageBroken,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                    ),
                                  ),
                                ),
                            if (message.revoked ||
                                message.content.isNotEmpty ||
                                message.replyPreview != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DesignTokens.spacingMD,
                                  vertical:
                                      DesignTokens.spacingSM +
                                      DesignTokens.spacingXS,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!message.revoked &&
                                        message.replyPreview != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: DesignTokens.spacingSM,
                                        ),
                                        child: Text(
                                          '↪ ${message.replyPreview}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: mine
                                                    ? AppColors.white70
                                                    : AppColors.textSecondary,
                                              ),
                                        ),
                                      ),
                                    if (message.revoked)
                                      Text(
                                        message.preview,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                      )
                                    else if (message.content.isNotEmpty)
                                      Text(
                                        message.content,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: color,
                                              height: 1.35,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            if (!message.revoked && !hasImage)
                              for (final url in message.mediaUrls)
                                TextButton.icon(
                                  onPressed: () => _open(context, url),
                                  icon: Icon(AppIcons.article, color: color),
                                  label: Text(
                                    'Mở tệp đính kèm',
                                    style: TextStyle(color: color),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (receipt != null)
            Padding(
              padding: const EdgeInsets.only(
                top: DesignTokens.spacingXS,
                right: DesignTokens.spacingXS,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.success,
                    size: DesignTokens.spacingMD,
                    color: receipt == 'Đã xem'
                        ? AppColors.primary600
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: DesignTokens.spacingXS),
                  Text(
                    receipt!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
