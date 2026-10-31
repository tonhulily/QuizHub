import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

enum LoadStatus { loading, loaded, failure }

class LoadState<T> extends Equatable {
  final LoadStatus status;
  final T? data;
  final ApiException? error;

  const LoadState({this.status = LoadStatus.loading, this.data, this.error});

  @override
  List<Object?> get props => [status, data, error];
}

/// Tải MỘT đối tượng (chi tiết phiên, thống kê câu hỏi...). Danh sách phân
/// trang thì dùng `PagedCubit`.
class LoadCubit<T> extends Cubit<LoadState<T>> {
  final Future<T> Function() _loader;

  /// [initial]: đã có sẵn dữ liệu (vd đề vừa sinh) thì hiện ngay, không gọi
  /// [load] lần đầu.
  LoadCubit(this._loader, {T? initial})
    : super(
        initial == null
            ? LoadState<T>()
            : LoadState<T>(status: LoadStatus.loaded, data: initial),
      );

  /// [silent]: giữ dữ liệu đang hiển thị trong lúc tải lại (sau khi sửa).
  ///
  /// Rời màn hình trước khi tải xong thì cubit đã đóng: bỏ kết quả, không emit.
  Future<void> load({bool silent = false}) async {
    if (!silent || state.data == null) emit(LoadState<T>());
    try {
      final data = await _loader();
      if (isClosed) return;
      emit(LoadState<T>(status: LoadStatus.loaded, data: data));
    } on ApiException catch (e) {
      if (isClosed) return;
      if (silent && state.data != null) {
        emit(
          LoadState<T>(status: LoadStatus.loaded, data: state.data, error: e),
        );
      } else {
        emit(LoadState<T>(status: LoadStatus.failure, error: e));
      }
    }
  }
}
