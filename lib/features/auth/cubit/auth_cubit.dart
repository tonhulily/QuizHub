import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/session_events.dart';
import '../../../data/repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;

  /// true nếu bị đăng xuất do phiên hết hạn (hiển thị thông báo ở Login)
  final bool sessionExpired;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.sessionExpired = false,
  });

  @override
  List<Object?> get props => [status, sessionExpired];
}

/// Trạng thái phiên đăng nhập toàn app.
///
/// - `bootstrap()` khi mở app: có token => authenticated.
/// - Lắng nghe [SessionEvents] (refresh token thất bại) => unauthenticated.
/// - UI (app.dart) lắng nghe cubit này để điều hướng về Login.
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;
  late final StreamSubscription<void> _expiredSub;

  AuthCubit(this._repo, SessionEvents events) : super(const AuthState()) {
    _expiredSub = events.onSessionExpired.listen((_) => _onExpired());
  }

  void bootstrap() {
    emit(
      AuthState(
        status: _repo.hasSession
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
      ),
    );
  }

  /// Gọi sau khi login thành công.
  void loggedIn() => emit(const AuthState(status: AuthStatus.authenticated));

  Future<void> logout() async {
    await _repo.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onExpired() async {
    if (state.status == AuthStatus.unauthenticated) return;
    await _repo.clearLocalSession();
    emit(
      const AuthState(status: AuthStatus.unauthenticated, sessionExpired: true),
    );
  }

  @override
  Future<void> close() {
    _expiredSub.cancel();
    return super.close();
  }
}
