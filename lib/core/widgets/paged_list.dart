import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/paged_cubit.dart';
import '../design_system/design_tokens.dart';
import 'state_views.dart';
import '../design_system/app_icons.dart';

/// Danh sách phân trang chuẩn: loading / lỗi / trống / pull-to-refresh /
/// kéo lên để tải thêm.
///
/// Dùng cùng [PagedCubit]:
/// ```dart
/// BlocProvider(
///   create: (_) => PagedCubit<PostModel>(loader)..load(),
///   child: PagedListView<PostModel>(itemBuilder: (c, post) => PostCard(post: post)),
/// )
/// ```
class PagedListView<T> extends StatefulWidget {
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? header;
  final Widget? emptyView;
  final Widget? loadingView;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;

  /// Ghi đè hành vi kéo-để-làm-mới (mặc định: `PagedCubit.refresh`).
  final Future<void> Function()? onRefresh;

  const PagedListView({
    super.key,
    required this.itemBuilder,
    this.header,
    this.emptyView,
    this.loadingView,
    this.padding = const EdgeInsets.all(DesignTokens.screenPadding),
    this.itemSpacing = 12,
    this.onRefresh,
  });

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!_controller.hasClients) return;
      final p = _controller.position;
      if (p.pixels >= p.maxScrollExtent - 300) {
        context.read<PagedCubit<T>>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PagedCubit<T>>();

    return BlocBuilder<PagedCubit<T>, PagedState<T>>(
      builder: (context, state) {
        final loading =
            state.status == PagedStatus.loading ||
            state.status == PagedStatus.initial;
        if (loading || state.status == PagedStatus.failure) {
          final body = loading
              ? (widget.loadingView ?? const PostListSkeleton())
              : ErrorView(
                  error: state.error,
                  onRetry: cubit.load,
                  compact: widget.header != null,
                );
          if (widget.header == null) return body;
          // Có header (vd trang cá nhân): vẫn hiển thị header khi nội dung đang tải/lỗi
          return ListView(
            controller: _controller,
            padding: widget.padding,
            children: [
              widget.header!,
              SizedBox(height: loading ? 480 : 260, child: body),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: widget.onRefresh ?? cubit.refresh,
          child: state.isEmpty
              ? ListView(
                  controller: _controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: widget.padding,
                  children: [
                    if (widget.header != null) widget.header!,
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.4,
                      child:
                          widget.emptyView ??
                          const EmptyView(title: 'Chưa có dữ liệu'),
                    ),
                  ],
                )
              : ListView.separated(
                  controller: _controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: widget.padding,
                  itemCount:
                      state.items.length +
                      (widget.header != null ? 1 : 0) +
                      1, // footer
                  separatorBuilder: (_, _) =>
                      SizedBox(height: widget.itemSpacing),
                  itemBuilder: (context, index) {
                    final offset = widget.header != null ? 1 : 0;
                    if (index == 0 && widget.header != null) {
                      return widget.header!;
                    }
                    final i = index - offset;
                    if (i >= state.items.length) {
                      return _Footer(state: state, onRetry: cubit.loadMore);
                    }
                    return widget.itemBuilder(context, state.items[i]);
                  },
                ),
        );
      },
    );
  }
}

class _Footer<T> extends StatelessWidget {
  final PagedState<T> state;
  final VoidCallback onRetry;

  const _Footer({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
        ),
      );
    }
    if (state.error != null && state.hasNext) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(AppIcons.refresh),
          label: const Text('Tải thêm thất bại. Thử lại'),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}
