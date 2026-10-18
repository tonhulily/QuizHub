import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/cursor_page.dart';
import '../network/api_exception.dart';

enum PagedStatus { initial, loading, loaded, failure }

class PagedState<T> extends Equatable {
  final PagedStatus status;
  final List<T> items;
  final String? after;
  final bool hasNext;
  final bool loadingMore;
  final bool refreshing;
  final ApiException? error;

  const PagedState({
    this.status = PagedStatus.initial,
    this.items = const [],
    this.after,
    this.hasNext = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.error,
  });

  bool get isEmpty => items.isEmpty;

  PagedState<T> copyWith({
    PagedStatus? status,
    List<T>? items,
    String? after,
    bool? hasNext,
    bool? loadingMore,
    bool? refreshing,
    ApiException? error,
    bool clearError = false,
  }) => PagedState<T>(
    status: status ?? this.status,
    items: items ?? this.items,
    after: after ?? this.after,
    hasNext: hasNext ?? this.hasNext,
    loadingMore: loadingMore ?? this.loadingMore,
    refreshing: refreshing ?? this.refreshing,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    status,
    items,
    after,
    hasNext,
    loadingMore,
    refreshing,
    error,
  ];
}

typedef PageLoader<T> = Future<CursorPage<T>> Function(String? after);

/// Cubit phân trang theo con trỏ DÙNG CHUNG cho mọi danh sách
/// (bảng tin, bài viết cá nhân, bạn bè, thông báo, tìm kiếm...).
///
/// ```dart
/// PagedCubit<PostModel>((after) => repo.myPosts(after: after))..load();
/// ```
/// UI: `BlocBuilder` + `PagedListView` (core/widgets/paged_list.dart).
class PagedCubit<T> extends Cubit<PagedState<T>> {
  final PageLoader<T> _loader;

  PagedCubit(this._loader, {List<T>? initialItems})
    : super(
        initialItems == null
            ? const PagedState()
            : PagedState(status: PagedStatus.loaded, items: initialItems),
      );

  /// Tải trang đầu. Nếu đã có dữ liệu (cache) thì không hiện loading toàn màn.
  Future<void> load() async {
    final hasData = state.items.isNotEmpty;
    emit(
      state.copyWith(
        status: hasData ? PagedStatus.loaded : PagedStatus.loading,
        refreshing: hasData,
        clearError: true,
      ),
    );
    await _fetchFirst();
  }

  /// Kéo để làm mới (pull-to-refresh) - giữ dữ liệu cũ khi đang tải.
  Future<void> refresh() async {
    emit(state.copyWith(refreshing: true, clearError: true));
    await _fetchFirst();
  }

  Future<void> _fetchFirst() async {
    try {
      final page = await _loader(null);
      emit(
        PagedState<T>(
          status: PagedStatus.loaded,
          items: page.items,
          after: page.after,
          hasNext: page.hasNext,
        ),
      );
    } on ApiException catch (e) {
      if (e.isNoMoreData) {
        emit(const PagedState(status: PagedStatus.loaded));
      } else if (state.items.isNotEmpty) {
        // Giữ dữ liệu hiện có, chỉ báo lỗi để UI hiển thị snackbar nếu muốn
        emit(state.copyWith(refreshing: false, error: e));
      } else {
        emit(PagedState<T>(status: PagedStatus.failure, error: e));
      }
    }
  }

  /// Tải trang kế tiếp (gọi khi cuộn gần cuối).
  Future<void> loadMore() async {
    if (!state.hasNext ||
        state.loadingMore ||
        state.status != PagedStatus.loaded) {
      return;
    }
    emit(state.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await _loader(state.after);
      emit(
        state.copyWith(
          items: [...state.items, ...page.items],
          after: page.after,
          hasNext: page.hasNext,
          loadingMore: false,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          loadingMore: false,
          hasNext: e.isNoMoreData ? false : state.hasNext,
          error: e.isNoMoreData ? null : e,
        ),
      );
    }
  }

  // ---- Chỉnh sửa danh sách cục bộ (sau khi sửa/xoá/đăng) ----

  void replaceWhere(bool Function(T) test, T newItem) => emit(
    state.copyWith(items: [for (final i in state.items) test(i) ? newItem : i]),
  );

  void removeWhere(bool Function(T) test) =>
      emit(state.copyWith(items: state.items.where((i) => !test(i)).toList()));

  void insertFirst(T item) => emit(
    state.copyWith(items: [item, ...state.items], status: PagedStatus.loaded),
  );
}
