import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../di/locator.dart';

class ConversationsView extends StatefulWidget {
  const ConversationsView({super.key});
  @override
  State<ConversationsView> createState() => _ConversationsViewState();
}

class _ConversationsViewState extends State<ConversationsView> {
  late final _conversations = PagedCubit<ChatConversation>(
    (after) => getIt<ChatRepository>().conversations(after: after),
  )..load();

  @override
  void dispose() {
    _conversations.close();
    super.dispose();
  }

  Future<void> _open(ChatConversation conversation) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.chatDetail,
      arguments: ChatTarget.conversation(conversation),
    );
    if (mounted) await _conversations.refresh();
  }

  void _search() => Navigator.of(context).pushNamed(AppRoutes.searchUsers);

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _conversations,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        actions: [
          IconButton(
            onPressed: _search,
            icon: const Icon(AppIcons.edit),
            tooltip: 'Cuộc trò chuyện mới',
          ),
        ],
      ),
      body: PagedListView<ChatConversation>(
        padding: EdgeInsets.zero,
        itemSpacing: 0,
        emptyView: EmptyView(
          icon: AppIcons.messenger,
          title: 'Chưa có cuộc trò chuyện',
          message: 'Mở hồ sơ một người và chọn Nhắn tin.',
          action: TextButton(
            onPressed: _search,
            child: const Text('Tìm người để nhắn tin'),
          ),
        ),
        itemBuilder: (context, conversation) => ListTile(
          key: ValueKey('conversation_${conversation.conversationId}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: UserAvatar(
            name: conversation.title,
            avatarUrl: conversation.avatarUrl,
            size: 52,
          ),
          title: Text(
            conversation.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: conversation.unreadCount > 0
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            conversation.lastMessage?.preview ?? 'Bắt đầu cuộc trò chuyện',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                TimeFormat.ago(conversation.updatedAt),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (conversation.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${conversation.unreadCount}',
                    style: const TextStyle(color: AppColors.white),
                  ),
                ),
            ],
          ),
          onTap: () => _open(conversation),
        ),
      ),
    ),
  );
}
