import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/chat_realtime.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/models/media_item.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/media_repository.dart';
import '../../../di/locator.dart';
import '../../../shared/media/media_viewer.dart';
import '../../../shared/media/image_picking.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../cubit/chat_detail_cubit.dart';
import '../widgets/connection_banner.dart';

class ChatDetailView extends StatefulWidget {
  final ChatTarget target;
  const ChatDetailView({super.key, required this.target});
  @override
  State<ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends State<ChatDetailView>
    with WidgetsBindingObserver {
  late final int _myId = context.read<ProfileCubit>().state.profile!.userId;
  late final _chat = ChatDetailCubit(
    getIt<ChatRepository>(),
    target: widget.target,
    myId: _myId,
    realtime: getIt<ChatRealtime>(),
  )..load();
  final _scroll = ScrollController();
  final _draft = TextEditingController();
  MediaItem? _attachment;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 180) {
        _chat.loadMore();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draft.dispose();
    _chat.close();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    _chat.setActive(active);
    if (active) {
      getIt<ChatRealtime>().resume();
      _chat.load();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      getIt<ChatRealtime>().pause();
    }
  }

  Future<void> _profile(int id) async {
    _chat.setActive(false);
    await Navigator.of(context).pushNamed(AppRoutes.userProfile, arguments: id);
    if (mounted) {
      _chat.setActive(true);
      await _chat.load();
    }
  }

  Future<void> _pickImage() async {
    setState(() => _uploading = true);
    final uploaded = await pickAndUploadImage(
      context,
      purpose: MediaPurpose.chat,
    );
    if (mounted) {
      setState(() {
        _uploading = false;
        if (uploaded != null) _attachment = uploaded.toMediaItem();
      });
    }
  }

  Future<void> _send() async {
    if (_chat.state.unconfirmed) {
      final found = await _chat.reconcilePending();
      if (!mounted) return;
      if (found) {
        _draft.clear();
        setState(() => _attachment = null);
        return;
      }
      final retry = await showConfirmDialog(
        context,
        title: 'Gửi lại tin nhắn?',
        message:
            'Chưa thấy tin trong lịch sử. Gửi lại có thể tạo tin trùng nếu máy chủ đang xử lý chậm.',
        confirmLabel: 'Gửi lại',
      );
      if (!retry || !mounted) return;
    }
    final error = await _chat.send(
      _draft.text,
      messageType: _attachment == null ? 'TEXT' : 'IMAGE',
      mediaUrls: _attachment == null ? const [] : [_attachment!.url],
    );
    if (!mounted) return;
    if (error != null) {
      AppFeedback.error(context, error);
    } else {
      _draft.clear();
      setState(() => _attachment = null);
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Widget _composer(ChatDetailState state) {
    final ready =
        state.connection == ChatConnection.connected &&
        !state.sending &&
        !_uploading;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachment != null)
            ListTile(
              dense: true,
              leading: const Icon(AppIcons.photos),
              title: const Text('Ảnh đính kèm'),
              onTap: () => MediaViewer.open(context, [_attachment!]),
              trailing: IconButton(
                tooltip: 'Gỡ ảnh',
                onPressed: state.sending
                    ? null
                    : () => setState(() => _attachment = null),
                icon: const Icon(AppIcons.close),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Đính kèm ảnh',
                  onPressed: ready && !state.unconfirmed ? _pickImage : null,
                  icon: const Icon(AppIcons.photos),
                ),
                Expanded(
                  child: TextField(
                    controller: _draft,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    readOnly: state.sending || state.unconfirmed,
                    onChanged: (value) {
                      _chat.inputChanged(value);
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn…',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                if (state.sending || _uploading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: state.unconfirmed
                        ? 'Gửi lại tin nhắn'
                        : 'Gửi tin nhắn',
                    onPressed:
                        ready &&
                            (_draft.text.trim().isNotEmpty ||
                                _attachment != null)
                        ? _send
                        : null,
                    icon: const Icon(AppIcons.send),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _messageMenu(ChatMessage message) async {
    if (message.revoked) return;
    final scope = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Xoá ở phía tôi'),
              onTap: () => Navigator.pop(ctx, false),
            ),
            if (message.senderId == _myId)
              ListTile(
                title: const Text('Thu hồi với mọi người'),
                onTap: () => Navigator.pop(ctx, true),
              ),
          ],
        ),
      ),
    );
    if (scope == null || !mounted) return;
    final error = await _chat.delete(message, forEveryone: scope);
    if (error != null && mounted) AppFeedback.error(context, error);
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _chat,
    child: BlocBuilder<ChatDetailCubit, ChatDetailState>(
      builder: (context, state) {
        final conversation = state.conversation;
        final title =
            conversation?.title ??
            widget.target.user?.fullName ??
            'Cuộc trò chuyện';
        final peerId =
            conversation?.peer(_myId)?.userId ?? widget.target.user?.userId;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                UserAvatar(
                  name: title,
                  avatarUrl:
                      conversation?.avatarUrl ?? widget.target.user?.avatarUrl,
                  size: 34,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              if (peerId != null)
                IconButton(
                  icon: const Icon(AppIcons.person),
                  tooltip: 'Xem hồ sơ',
                  onPressed: () => _profile(peerId),
                ),
              IconButton(
                onPressed: _chat.load,
                icon: const Icon(AppIcons.refresh),
                tooltip: 'Làm mới tin nhắn',
              ),
            ],
          ),
          body: state.status == ChatStatus.loading
              ? const LoadingView()
              : state.status == ChatStatus.failure
              ? ErrorView(error: state.error, onRetry: _chat.load)
              : Column(
                  children: [
                    ChatConnectionBanner(
                      connection: state.connection,
                      onRetry: () => getIt<ChatRealtime>().reconnect(),
                    ),
                    if (state.error != null)
                      ErrorView(
                        error: state.error,
                        compact: true,
                        onRetry: _chat.load,
                      ),
                    if (state.refreshing) const LinearProgressIndicator(),
                    Expanded(
                      child: state.messages.isEmpty
                          ? const EmptyView(
                              icon: AppIcons.messenger,
                              title: 'Chưa có tin nhắn',
                            )
                          : ListView.builder(
                              controller: _scroll,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              itemCount: state.messages.length + 1,
                              itemBuilder: (context, i) {
                                if (i == state.messages.length) {
                                  return state.loadingMore
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : state.hasNext
                                      ? Center(
                                          child: TextButton(
                                            onPressed: _chat.loadMore,
                                            child: const Text(
                                              'Tin nhắn trước đó',
                                            ),
                                          ),
                                        )
                                      : const SizedBox(height: 12);
                                }
                                final message = state.messages[i];
                                return _MessageBubble(
                                  key: ValueKey(message.messageId),
                                  message: message,
                                  mine: message.senderId == _myId,
                                  onLongPress: () => _messageMenu(message),
                                );
                              },
                            ),
                    ),
                    if (state.isTyping)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Đang nhập…'),
                      ),
                    if (state.messages.isNotEmpty &&
                        state.messages.first.senderId == _myId &&
                        state.lastReadMessageId >=
                            state.messages.first.messageId)
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: Text('Đã xem'),
                        ),
                      ),
                    _composer(state),
                  ],
                ),
        );
      },
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final VoidCallback onLongPress;
  const _MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary50 : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine && message.senderName.isNotEmpty)
              Text(
                message.senderName,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            if (!message.revoked && message.replyPreview != null)
              Text(
                '↪ ${message.replyPreview}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (message.revoked)
              Text(
                message.preview,
                style: const TextStyle(fontStyle: FontStyle.italic),
              )
            else ...[
              if (message.content.isNotEmpty) SelectableText(message.content),
              for (final url in message.mediaUrls)
                TextButton.icon(
                  icon: Icon(
                    message.messageType == 'VIDEO'
                        ? AppIcons.play
                        : AppIcons.photos,
                  ),
                  label: Text(
                    message.messageType == 'VIDEO' ? 'Xem video' : 'Xem ảnh',
                  ),
                  onPressed: () => MediaViewer.open(context, [
                    MediaItem(
                      url: url,
                      type: message.messageType == 'VIDEO'
                          ? MediaType.video
                          : MediaType.image,
                    ),
                  ]),
                ),
            ],
            if (message.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  DateFormat(
                    'HH:mm · dd/MM',
                  ).format(message.createdAt!.toLocal()),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
