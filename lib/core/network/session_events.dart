import 'dart:async';

/// Sự kiện toàn cục của phiên đăng nhập.
///
/// Tầng network phát sự kiện, AuthCubit lắng nghe và điều hướng về Login.
/// Nhờ vậy network layer không phụ thuộc UI.
class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get onSessionExpired => _expired.stream;

  void notifySessionExpired() {
    if (!_expired.isClosed) _expired.add(null);
  }

  void dispose() => _expired.close();
}
