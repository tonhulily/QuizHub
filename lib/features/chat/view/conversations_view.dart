import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/chat_realtime.dart';
import '../../../core/services/blocked_users.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../di/locator.dart';
import '../../../shared/widgets/blocked_content.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../widgets/chat_tokens.dart';
import '../widgets/connection_banner.dart';

class ConversationsView extends StatefulWidget {
  const ConversationsView({super.key});
  @override
  State<ConversationsView> createState() => _ConversationsViewState();
}

class _ConversationsViewState extends State<ConversationsView>
    with WidgetsBindingObserver {
  late final _live = getIt<ChatRealtime>();
  late final _conversations = PagedCubit<ChatConversation>(
    (after) => getIt<ChatRepository>().conversations(after: after),
  );
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _searchedCursors = <String>{};
  Timer? _refresh;
  Timer? _searchDelay;
  String _query = '';
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscriptions.add(
      _conversations.stream.listen((state) => _continueSearch()),
    );
    _subscriptions.add(
      _live.events.listen((event) {
        if (event.kind == ChatEventKind.typing) return;
        _refresh?.cancel();
        _refresh = Timer(DesignTokens.animNormal, () {
          if (mounted) _reload();
        });
      }),
    );
    _subscriptions.add(
      _live.connections.listen((connection) {
        if (!mounted) return;
        setState(() {});
        if (connection == ChatConnection.connected &&
            _conversations.state.status == PagedStatus.loaded) {
          _reload();
        }
      }),
    );
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < ChatTokens.jumpThreshold) {
        _conversations.loadMore();
      }
    });
    _conversations.load();
    _live.acquire();
    if (getIt.isRegistered<BlockedUsers>()) {
      _subscriptions.add(
        getIt<BlockedUsers>().onChanged.listen((_) {
          if (mounted) {
            setState(() {});
            _reload();
          }
        }),
      );
    }
  }

  // Khi lọc, tiếp tục đọc các trang cũ để không kết luận nhầm là không có kết quả.
  void _continueSearch() {
    final state = _conversations.state;
    if (!mounted ||
        state.status != PagedStatus.loaded ||
        !state.hasNext ||
        state.loadingMore ||
        state.refreshing ||
        state.error != null) {
      return;
    }
    if (_query.isEmpty && !_unreadOnly && state.items.isNotEmpty) return;
    final cursor = state.after;
    if (cursor == null || !_searchedCursors.add(cursor)) return;
    scheduleMicrotask(() {
      if (mounted) _conversations.loadMore();
    });
  }

  Future<void> _reload() {
    _searchedCursors.clear();
    return _conversations.refresh();
  }

  void _filter(String query) {
    setState(() => _query = query.trim().toLowerCase());
    _searchedCursors.clear();
    _searchDelay?.cancel();
    _searchDelay = Timer(DesignTokens.animNormal, _continueSearch);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _live.resume();
      _reload();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _live.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    _searchDelay?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _live.release();
    _conversations.close();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(ChatConversation conversation) async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).pushNamed(
      AppRoutes.chatDetail,
      arguments: ChatTarget.conversation(conversation),
    );
    if (mounted) await _reload();
  }

  void _newConversation() =>
      Navigator.of(context).pushNamed(AppRoutes.searchUsers);

  bool _visible(ChatConversation row) {
    if (!getIt.isRegistered<BlockedUsers>()) return true;
    final blocks = getIt<BlockedUsers>();
    if (row.type == 'DIRECT' && row.members.isEmpty && blocks.ids.isNotEmpty) {
      return false;
    }
    return !row.members.any((m) => blocks.contains(m.userId));
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _conversations,
    child: Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text(
          'Đoạn chat',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DesignTokens.spacingSM),
            child: IconButton.filledTonal(
              tooltip: 'Cuộc trò chuyện mới',
              onPressed: _newConversation,
              icon: const Icon(AppIcons.edit),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ChatTokens.contentWidth),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spacingMD,
                  DesignTokens.spacingSM,
                  DesignTokens.spacingMD,
                  DesignTokens.spacingMD,
                ),
                child: TextField(
                  key: const ValueKey('conversation_search'),
                  controller: _search,
                  onChanged: _filter,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Tìm trong đoạn chat',
                    prefixIcon: const Icon(
                      AppIcons.search,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xoá tìm kiếm',
                            icon: const Icon(AppIcons.close),
                            onPressed: () {
                              _search.clear();
                              _filter('');
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    isDense: true,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spacingMD,
                  0,
                  DesignTokens.spacingMD,
                  DesignTokens.spacingSM,
                ),
                child: Row(
                  children: [
                    _filterChip('Tất cả', !_unreadOnly, false),
                    const SizedBox(width: DesignTokens.spacingSM),
                    _filterChip('Chưa đọc', _unreadOnly, true),
                  ],
                ),
              ),
              ChatConnectionBanner(
                connection: _live.connection,
                onRetry: () => _live.reconnect(),
              ),
              Expanded(
                child:
                    BlocBuilder<
                      PagedCubit<ChatConversation>,
                      PagedState<ChatConversation>
                    >(
                      builder: (context, state) {
                        if (state.status == PagedStatus.initial ||
                            state.status == PagedStatus.loading) {
                          return const LoadingView();
                        }
                        if (state.status == PagedStatus.failure) {
                          return ErrorView(
                            error: state.error,
                            onRetry: _conversations.load,
                          );
                        }
                        final myId = context
                            .read<ProfileCubit>()
                            .state
                            .profile
                            ?.userId;
                        final items = state.items
                            .where(
                              (row) =>
                                  _visible(row) &&
                                  (!_unreadOnly || row.unreadCount > 0) &&
                                  (_query.isEmpty ||
                                      '${row.title} ${row.lastMessage?.preview ?? ''}'
                                          .toLowerCase()
                                          .contains(_query)),
                            )
                            .toList();
                        return RefreshIndicator(
                          onRefresh: _reload,
                          child: ListView.builder(
                            controller: _scroll,
                            physics: const AlwaysScrollableScrollPhysics(),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.only(
                              bottom: DesignTokens.spacingMD,
                            ),
                            itemCount: items.length + 1,
                            itemBuilder: (context, i) {
                              if (i < items.length) {
                                final row = items[i];
                                return BlockedContent(
                                  userIds: row.members.map((m) => m.userId),
                                  child: _ConversationRow(
                                    conversation: row,
                                    myId: myId,
                                    onTap: () => _open(row),
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  if (items.isEmpty &&
                                      !state.loadingMore &&
                                      !state.refreshing)
                                    SizedBox(
                                      height:
                                          MediaQuery.sizeOf(context).height *
                                          .42,
                                      child: EmptyView(
                                        icon: _query.isNotEmpty
                                            ? AppIcons.search
                                            : AppIcons.messenger,
                                        title: _query.isNotEmpty
                                            ? 'Không tìm thấy cuộc trò chuyện'
                                            : _unreadOnly
                                            ? 'Bạn đã đọc hết tin nhắn'
                                            : 'Chưa có cuộc trò chuyện',
                                        message: _query.isNotEmpty
                                            ? 'Thử tìm tên hoặc nội dung khác.'
                                            : _unreadOnly
                                            ? 'Các đoạn chat chưa đọc sẽ hiện ở đây.'
                                            : 'Gửi lời chào để bắt đầu trò chuyện.',
                                        action: _query.isNotEmpty || _unreadOnly
                                            ? null
                                            : TextButton(
                                                onPressed: _newConversation,
                                                child: const Text(
                                                  'Nhắn tin mới',
                                                ),
                                              ),
                                      ),
                                    ),
                                  if (state.error != null)
                                    Padding(
                                      padding: const EdgeInsets.all(
                                        DesignTokens.spacingMD,
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            state.error!.message,
                                            textAlign: TextAlign.center,
                                          ),
                                          TextButton(
                                            onPressed: state.hasNext
                                                ? _conversations.loadMore
                                                : _reload,
                                            child: const Text('Thử lại'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (state.loadingMore || state.refreshing)
                                    const Padding(
                                      padding: EdgeInsets.all(
                                        DesignTokens.spacingMD,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  else if (state.hasNext && state.error == null)
                                    TextButton(
                                      onPressed: _conversations.loadMore,
                                      child: const Text(
                                        'Xem thêm cuộc trò chuyện',
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _filterChip(String label, bool selected, bool unread) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    selectedColor: AppColors.primary50,
    backgroundColor: AppColors.backgroundSecondary,
    side: BorderSide.none,
    labelStyle: TextStyle(
      color: selected ? AppColors.primary600 : AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    ),
    shape: const StadiumBorder(),
    onSelected: (_) {
      setState(() => _unreadOnly = unread);
      _searchedCursors.clear();
      _continueSearch();
    },
  );
}

class _ConversationRow extends StatelessWidget {
  final ChatConversation conversation;
  final int? myId;
  final VoidCallback onTap;
  const _ConversationRow({
    required this.conversation,
    required this.myId,
    required this.onTap,
  });

  String _time(DateTime? value) {
    if (value == null) return '';
    final date = value.toLocal();
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    }
    return DateFormat(
      date.year == now.year ? 'dd/MM' : 'dd/MM/yy',
    ).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unreadCount > 0;
    final last = c.lastMessage;
    final preview = last == null
        ? 'Bắt đầu cuộc trò chuyện'
        : '${last.senderId == myId ? 'Bạn: ' : ''}${last.preview}';
    return ListTile(
      key: ValueKey('conversation_${c.conversationId}'),
      minVerticalPadding: DesignTokens.spacingSM + DesignTokens.spacingXS,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingMD,
      ),
      leading: UserAvatar(
        name: c.title,
        avatarUrl: c.avatarUrl,
        size: ChatTokens.avatar,
      ),
      title: Text(
        c.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: DesignTokens.spacingXS),
        child: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: unread ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _time(c.updatedAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: unread ? AppColors.primary600 : AppColors.textSecondary,
            ),
          ),
          if (unread) ...[
            const SizedBox(height: DesignTokens.spacingXS),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacingSM,
                vertical: DesignTokens.spacingXS / 2,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primary600,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.all(
                  Radius.circular(DesignTokens.radiusXL),
                ),
              ),
              child: Text(
                c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
