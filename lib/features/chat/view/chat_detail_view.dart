import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/chat_realtime.dart';
import '../../../core/services/social_events.dart';
import '../../../core/services/blocked_users.dart';
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
import '../../../shared/widgets/blocked_content.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../cubit/chat_detail_cubit.dart';
import '../widgets/chat_message_tile.dart';
import '../widgets/chat_tokens.dart';
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
    socialEvents: getIt<SocialEvents>(),
    blocks: getIt.isRegistered<BlockedUsers>() ? getIt<BlockedUsers>() : null,
  )..load();
  final _scroll = ScrollController();
  final _draft = TextEditingController();
  MediaItem? _attachment;
  bool _uploading = false;
  bool _showJump = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      final show = _scroll.position.pixels > ChatTokens.jumpThreshold;
      if (show != _showJump) setState(() => _showJump = show);
      if (_scroll.position.pixels >=
          _scroll.position.maxScrollExtent - ChatTokens.jumpThreshold) {
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

  void _latest() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: DesignTokens.animNormal,
        curve: Curves.easeOut,
      );
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
      allowRetry: _chat.state.unconfirmed,
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

  Future<void> _messageMenu(ChatMessage message) async {
    if (message.revoked) return;
    final scope = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.content.isNotEmpty)
              ListTile(
                leading: const Icon(AppIcons.copy),
                title: const Text('Sao chép'),
                onTap: () => Navigator.pop(ctx, 'COPY'),
              ),
            ListTile(
              leading: const Icon(AppIcons.delete),
              title: const Text('Xoá ở phía tôi'),
              onTap: () => Navigator.pop(ctx, 'ME'),
            ),
            if (message.senderId == _myId)
              ListTile(
                title: const Text('Thu hồi với mọi người'),
                leading: const Icon(AppIcons.refresh),
                onTap: () => Navigator.pop(ctx, 'EVERYONE'),
              ),
          ],
        ),
      ),
    );
    if (scope == null || !mounted) return;
    if (scope == 'COPY') {
      await Clipboard.setData(ClipboardData(text: message.content));
      if (mounted) AppFeedback.success(context, 'Đã sao chép tin nhắn.');
      return;
    }
    final error = await _chat.delete(message, forEveryone: scope == 'EVERYONE');
    if (error != null && mounted) AppFeedback.error(context, error);
  }

  Widget _composer(ChatDetailState state) {
    final ready =
        state.connection == ChatConnection.connected &&
        state.accessVerified &&
        !state.sending &&
        !state.sendRestricted &&
        !state.checkingAccess &&
        !_uploading;
    final hasContent = _draft.text.trim().isNotEmpty || _attachment != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DesignTokens.spacingXS,
          DesignTokens.spacingSM,
          DesignTokens.spacingSM,
          DesignTokens.spacingSM,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_attachment != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: DesignTokens.spacingMD,
                  bottom: DesignTokens.spacingSM,
                ),
                child: SizedBox(
                  width: ChatTokens.attachmentSize + DesignTokens.spacingMD,
                  height: ChatTokens.attachmentSize + DesignTokens.spacingSM,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        right: DesignTokens.spacingMD,
                        top: DesignTokens.spacingSM,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusMD,
                          ),
                          child: InkWell(
                            onTap: () =>
                                MediaViewer.open(context, [_attachment!]),
                            child: CachedNetworkImage(
                              imageUrl: _attachment!.url,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const ColoredBox(
                                color: AppColors.chip,
                                child: Icon(AppIcons.photos),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filledTonal(
                          tooltip: 'Gỡ ảnh',
                          visualDensity: VisualDensity.compact,
                          onPressed: state.sending || state.unconfirmed
                              ? null
                              : () => setState(() => _attachment = null),
                          icon: const Icon(
                            AppIcons.close,
                            size: DesignTokens.spacingMD,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Đính kèm ảnh',
                  onPressed: ready && !state.unconfirmed ? _pickImage : null,
                  icon: const Icon(AppIcons.photosFill),
                  color: AppColors.primary600,
                ),
                Expanded(
                  child: TextField(
                    controller: _draft,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    readOnly:
                        state.sending ||
                        state.unconfirmed ||
                        state.sendRestricted,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (value) {
                      _chat.inputChanged(value);
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Tin nhắn',
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.backgroundSecondary,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacingMD,
                        vertical:
                            DesignTokens.spacingSM + DesignTokens.spacingXS,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusXL,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusXL,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusXL,
                        ),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.spacingXS),
                if (state.sending || _uploading)
                  const Padding(
                    padding: EdgeInsets.all(
                      DesignTokens.spacingSM + DesignTokens.spacingXS,
                    ),
                    child: SizedBox(
                      width: DesignTokens.spacingLG,
                      height: DesignTokens.spacingLG,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: state.unconfirmed
                        ? 'Gửi lại tin nhắn'
                        : hasContent
                        ? 'Gửi tin nhắn'
                        : 'Gửi lượt thích',
                    color: AppColors.primary600,
                    icon: Icon(hasContent ? AppIcons.send : AppIcons.likeFill),
                    onPressed: !ready
                        ? null
                        : hasContent
                        ? _send
                        : () {
                            setState(() => _draft.text = '👍');
                            _send();
                          },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _joins(ChatMessage a, ChatMessage? b) =>
      b != null &&
      a.senderId == b.senderId &&
      !a.revoked &&
      !b.revoked &&
      (a.createdAt == null ||
          b.createdAt == null ||
          a.createdAt!.difference(b.createdAt!).abs() <
              const Duration(minutes: 2));

  Widget _unavailable(String message) => Scaffold(
    appBar: AppBar(title: const Text('Cuộc trò chuyện không khả dụng')),
    body: EmptyView(
      icon: AppIcons.lock,
      title: 'Không thể xem cuộc trò chuyện',
      message: message,
    ),
  );

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _chat,
    child: BlocConsumer<ChatDetailCubit, ChatDetailState>(
      listenWhen: (previous, current) =>
          previous.messages.firstOrNull?.messageId !=
          current.messages.firstOrNull?.messageId,
      listener: (context, state) {
        if (!_showJump) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _latest();
          });
        }
      },
      builder: (context, state) => BlockedContent(
        userIds: [
          widget.target.user?.userId,
          ...?state.conversation?.members.map((u) => u.userId),
        ],
        blockedChild: _unavailable(BlockedUsers.unavailable.message),
        child: _body(state),
      ),
    ),
  );

  Widget _body(ChatDetailState state) {
    if (state.sendRestricted) return _unavailable(state.restrictionMessage);
    if (state.checkingAccess && !state.accessVerified && state.error == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cuộc trò chuyện')),
        body: const LoadingView(),
      );
    }
    final conversation = state.conversation;
    final peer = conversation?.peer(_myId) ?? widget.target.user;
    final title = conversation?.title ?? peer?.fullName ?? 'Cuộc trò chuyện';
    final avatar = conversation?.avatarUrl ?? peer?.avatarUrl;
    final lastOwn = state.messages
        .where((m) => m.senderId == _myId && !m.revoked)
        .firstOrNull
        ?.messageId;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        titleSpacing: 0,
        title: InkWell(
          onTap: peer == null ? null : () => _profile(peer.userId),
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          child: Row(
            children: [
              UserAvatar(
                name: title,
                avatarUrl: avatar,
                size: ChatTokens.headerAvatar,
              ),
              const SizedBox(
                width: DesignTokens.spacingSM + DesignTokens.spacingXS,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      state.isTyping ? 'Đang nhập…' : 'Đoạn chat riêng',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (peer != null)
            IconButton(
              tooltip: 'Xem hồ sơ',
              onPressed: () => _profile(peer.userId),
              icon: const Icon(AppIcons.infoOutline),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ChatTokens.contentWidth),
          child: Column(
            children: [
              ChatConnectionBanner(
                connection: state.connection,
                onRetry: () => getIt<ChatRealtime>().reconnect(),
              ),
              if (state.error != null && state.status != ChatStatus.failure)
                Material(
                  color: AppColors.warningLight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: DesignTokens.spacingMD,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.error!.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: state.refreshing ? null : _chat.load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.refreshing || state.checkingAccess)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child:
                    state.status == ChatStatus.failure && state.messages.isEmpty
                    ? ErrorView(error: state.error, onRetry: _chat.load)
                    : state.status == ChatStatus.loading
                    ? const LoadingView()
                    : Stack(
                        children: [
                          if (state.messages.isEmpty)
                            Center(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    DesignTokens.spacingLG,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      UserAvatar(
                                        name: title,
                                        avatarUrl: avatar,
                                        size: ChatTokens.attachmentSize,
                                      ),
                                      const SizedBox(
                                        height: DesignTokens.spacingMD,
                                      ),
                                      Text(
                                        title,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(
                                        height: DesignTokens.spacingSM,
                                      ),
                                      const Text(
                                        'Bắt đầu cuộc trò chuyện bằng một lời chào.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (state.messages.isNotEmpty)
                            ListView.builder(
                              key: const ValueKey('chat_history'),
                              controller: _scroll,
                              reverse: true,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.all(
                                DesignTokens.spacingMD,
                              ),
                              itemCount: state.messages.length + 1,
                              itemBuilder: (context, i) {
                                if (i == state.messages.length) {
                                  return state.loadingMore
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(
                                              DesignTokens.spacingSM,
                                            ),
                                            child: CircularProgressIndicator(),
                                          ),
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
                                      : const SizedBox(
                                          height: DesignTokens.spacingMD,
                                        );
                                }
                                final message = state.messages[i];
                                final older = i + 1 < state.messages.length
                                    ? state.messages[i + 1]
                                    : null;
                                final newer = i > 0
                                    ? state.messages[i - 1]
                                    : null;
                                final separator =
                                    older == null ||
                                    (message.createdAt != null &&
                                        older.createdAt != null &&
                                        message.createdAt!
                                                .difference(older.createdAt!)
                                                .abs() >=
                                            const Duration(hours: 1));
                                return Column(
                                  children: [
                                    if (separator && message.createdAt != null)
                                      _TimeSeparator(time: message.createdAt!),
                                    ChatMessageTile(
                                      key: ValueKey(message.messageId),
                                      message: message,
                                      mine: message.senderId == _myId,
                                      joinsOlder:
                                          !separator && _joins(message, older),
                                      joinsNewer: _joins(message, newer),
                                      avatarUrl: peer?.avatarUrl,
                                      userIds:
                                          conversation?.members.map(
                                            (u) => u.userId,
                                          ) ??
                                          const [],
                                      onLongPress: () => _messageMenu(message),
                                      receipt: message.messageId == lastOwn
                                          ? state.lastReadMessageId >=
                                                    message.messageId
                                                ? 'Đã xem'
                                                : 'Đã gửi'
                                          : null,
                                    ),
                                  ],
                                );
                              },
                            ),
                          if (_showJump)
                            Positioned(
                              right: DesignTokens.spacingMD,
                              bottom: DesignTokens.spacingSM,
                              child: IconButton.filledTonal(
                                tooltip: 'Về tin nhắn mới nhất',
                                onPressed: _latest,
                                icon: const Icon(AppIcons.dropdown),
                              ),
                            ),
                        ],
                      ),
              ),
              if (state.isTyping)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacingMD,
                      vertical: DesignTokens.spacingSM,
                    ),
                    child: Text(
                      'Đang nhập…',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              _composer(state),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeSeparator extends StatelessWidget {
  final DateTime time;
  const _TimeSeparator({required this.time});
  @override
  Widget build(BuildContext context) {
    final local = time.toLocal();
    final now = DateTime.now();
    final date = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    final label = date == today
        ? 'Hôm nay'
        : date == today.subtract(const Duration(days: 1))
        ? 'Hôm qua'
        : DateFormat('dd/MM/yyyy').format(local);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spacingMD),
      child: Text(
        '$label, ${DateFormat('HH:mm').format(local)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
