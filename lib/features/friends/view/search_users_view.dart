import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/repositories/user_search_repository.dart';
import '../../../di/locator.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../cubit/user_search_cubit.dart';
import '../widgets/person_card.dart';

/// Tìm người dùng theo tên, mã SV/GV hoặc email (kiểu thanh tìm kiếm Facebook).
class SearchUsersView extends StatelessWidget {
  const SearchUsersView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UserSearchCubit(getIt<UserSearchRepository>()),
      child: const _SearchBody(),
    );
  }
}

class _SearchBody extends StatefulWidget {
  const _SearchBody();

  @override
  State<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<_SearchBody> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        context.read<UserSearchCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openProfile(int userId) {
    final myId = context.read<ProfileCubit>().state.profile?.userId;
    Navigator.of(context).pushNamed(
      userId == myId ? AppRoutes.myProfile : AppRoutes.userProfile,
      arguments: userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<UserSearchCubit>();
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            textAlignVertical: TextAlignVertical.center,
            onChanged: (v) {
              setState(() {});
              cubit.onQueryChanged(v);
            },
            onSubmitted: cubit.submit,
            decoration: InputDecoration(
              hintText: 'Tìm tên, mã SV/GV hoặc email',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              // Căn chữ giữa theo chiều dọc: bỏ padding mặc định của theme và ép
              // biểu tượng cao đúng bằng khung 42px
              isDense: true,
              contentPadding: EdgeInsets.zero,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 42,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 42,
              ),
              prefixIcon: const Icon(AppIcons.search, size: 22),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(AppIcons.close, size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() {});
                        cubit.onQueryChanged('');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<UserSearchCubit, UserSearchState>(
        builder: (context, state) {
          switch (state.status) {
            case UserSearchStatus.idle:
              return const EmptyView(
                icon: AppIcons.search,
                title: 'Tìm bạn bè',
                message:
                    'Nhập tên, mã số SV/GV hoặc email của người bạn muốn tìm.',
              );
            case UserSearchStatus.loading:
              return const LoadingView();
            case UserSearchStatus.failure:
              return ErrorView(
                error: state.error,
                onRetry: () => cubit.submit(state.query),
              );
            case UserSearchStatus.loaded:
              if (state.items.isEmpty) {
                return EmptyView(
                  icon: AppIcons.search,
                  title: 'Không tìm thấy ai',
                  message: state.emailMode
                      ? 'Không có tài khoản nào dùng email này.'
                      : 'Thử tên khác, mã SV/GV hoặc email đầy đủ.',
                );
              }
              return ListView.separated(
                controller: _scroll,
                padding: EdgeInsets.zero,
                itemCount: state.items.length + 2,
                separatorBuilder: (_, i) => i == 0 || i > state.items.length
                    ? const SizedBox.shrink()
                    : const Divider(height: 1, indent: 88),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Container(
                      color: AppColors.white,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Text(
                        state.emailMode
                            ? 'Kết quả theo email'
                            : '${state.totalHits} kết quả',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }
                  if (i == state.items.length + 1) {
                    return SizedBox(
                      height: 56,
                      child: state.loadingMore
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              ),
                            )
                          : null,
                    );
                  }
                  final u = state.items[i - 1];
                  return PersonCard(
                    key: ValueKey('sr_${u.userId}'),
                    name: u.fullName,
                    subtitle: u.subtitle,
                    avatarUrl: u.avatarUrl,
                    frameUrl: u.frameUrl,
                    onTap: () => _openProfile(u.userId),
                    trailing: const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Icon(
                        AppIcons.chevronRight,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  );
                },
              );
          }
        },
      ),
    );
  }
}
