import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/auth_session.dart';
import '../../../data/repositories/auth_repository.dart';

enum LoginStatus { idle, submitting, success, failure }

class LoginState extends Equatable {
  final LoginStatus status;
  final AuthSession? session;
  final ApiException? error;

  const LoginState({this.status = LoginStatus.idle, this.session, this.error});

  bool get isSubmitting => status == LoginStatus.submitting;

  @override
  List<Object?> get props => [status, session, error];
}

/// Logic đăng nhập (scope theo màn hình Login).
class LoginCubit extends Cubit<LoginState> {
  final AuthRepository _repo;

  LoginCubit(this._repo) : super(const LoginState());

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting) return;
    emit(const LoginState(status: LoginStatus.submitting));
    try {
      final session = await _repo.login(email: email, password: password);
      emit(LoginState(status: LoginStatus.success, session: session));
    } on ApiException catch (e) {
      emit(LoginState(status: LoginStatus.failure, error: e));
    }
  }
}
