import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/push_settings.dart';
import '../../../data/repositories/push_settings_repository.dart';

enum PushSettingsStatus { initial, loading, ready, saving, failure }

class PushSettingsState {
  final PushSettingsStatus status;
  final PushSettings? original;
  final PushSettings? draft;
  final String? errorMessage;
  final bool saveCompleted;

  const PushSettingsState({
    this.status = PushSettingsStatus.initial,
    this.original,
    this.draft,
    this.errorMessage,
    this.saveCompleted = false,
  });

  bool get isLoading => status == PushSettingsStatus.loading;
  bool get isSaving => status == PushSettingsStatus.saving;
  bool get hasSettings => draft != null && original != null;

  bool get isDirty {
    if (draft == null || original == null) return false;
    return jsonEncode(draft!.toJson()) != jsonEncode(original!.toJson());
  }

  PushSettingsState copyWith({
    PushSettingsStatus? status,
    PushSettings? original,
    PushSettings? draft,
    String? errorMessage,
    bool clearError = false,
    bool? saveCompleted,
  }) => PushSettingsState(
    status: status ?? this.status,
    original: original ?? this.original,
    draft: draft ?? this.draft,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    saveCompleted: saveCompleted ?? false,
  );
}

/// Chỉ giữ thay đổi ở local state. API PUT chỉ được gọi khi người dùng nhấn Lưu.
class PushSettingsCubit extends Cubit<PushSettingsState> {
  final PushSettingsRepository _repository;

  PushSettingsCubit(this._repository) : super(const PushSettingsState());

  Future<void> load() async {
    emit(
      PushSettingsState(
        status: PushSettingsStatus.loading,
        original: state.original,
        draft: state.draft,
      ),
    );
    try {
      final settings = await _repository.getSettings();
      emit(
        PushSettingsState(
          status: PushSettingsStatus.ready,
          original: settings,
          draft: settings,
        ),
      );
    } catch (error) {
      emit(
        PushSettingsState(
          status: state.hasSettings
              ? PushSettingsStatus.ready
              : PushSettingsStatus.failure,
          original: state.original,
          draft: state.draft,
          errorMessage: _messageOf(error),
        ),
      );
    }
  }

  void updateDraft(PushSettings settings) {
    if (!state.hasSettings || state.isSaving) return;
    emit(
      PushSettingsState(
        status: PushSettingsStatus.ready,
        original: state.original,
        draft: settings,
      ),
    );
  }

  void discardChanges() {
    if (!state.hasSettings || state.isSaving) return;
    emit(
      PushSettingsState(
        status: PushSettingsStatus.ready,
        original: state.original,
        draft: state.original,
      ),
    );
  }

  Future<void> save() async {
    final draft = state.draft;
    if (draft == null || !state.isDirty || state.isSaving) return;

    final original = state.original;
    emit(
      PushSettingsState(
        status: PushSettingsStatus.saving,
        original: original,
        draft: draft,
      ),
    );

    try {
      final saved = await _repository.updateSettings(draft);
      emit(
        PushSettingsState(
          status: PushSettingsStatus.ready,
          original: saved,
          draft: saved,
          saveCompleted: true,
        ),
      );
    } catch (error) {
      // Giữ nguyên draft để người dùng có thể thử lưu lại.
      emit(
        PushSettingsState(
          status: PushSettingsStatus.ready,
          original: original,
          draft: draft,
          errorMessage: _messageOf(error),
        ),
      );
    }
  }

  String _messageOf(Object error) {
    try {
      return (error as dynamic).message?.toString() ??
          'Đã xảy ra lỗi. Vui lòng thử lại.';
    } catch (_) {
      return 'Đã xảy ra lỗi. Vui lòng thử lại.';
    }
  }
}
