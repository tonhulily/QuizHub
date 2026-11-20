import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/component_tokens.dart';
import '../../core/design_system/design_tokens.dart';
import '../../core/design_system/spacing_helper.dart';
import '../../data/models/push_settings.dart';
import '../../di/locator.dart';
import 'cubit/push_settings_cubit.dart';

class PushSettingsView extends StatelessWidget {
  const PushSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PushSettingsCubit(getIt())..load(),
      child: const _PushSettingsBody(),
    );
  }
}

class _PushSettingsBody extends StatelessWidget {
  const _PushSettingsBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('Cài đặt thông báo'),
        backgroundColor: AppColors.white,
      ),
      body: BlocConsumer<PushSettingsCubit, PushSettingsState>(
        listenWhen: (previous, current) =>
            current.errorMessage != null &&
                previous.errorMessage != current.errorMessage ||
            current.saveCompleted,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppColors.errorDark,
                ),
              );
          } else if (state.saveCompleted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Đã lưu cài đặt thông báo.')),
              );
          }
        },
        builder: (context, state) {
          if (state.isLoading && !state.hasSettings) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!state.hasSettings) {
            return _LoadError(
              message:
                  state.errorMessage ?? 'Không tải được cài đặt thông báo.',
              onRetry: () => context.read<PushSettingsCubit>().load(),
            );
          }

          final settings = state.draft!;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    DesignTokens.screenPadding,
                    DesignTokens.spacingMD,
                    DesignTokens.screenPadding,
                    DesignTokens.spacingLG,
                  ),
                  children: [
                    _IntroCard(),
                    SpacingHelper.vMD,
                    _SettingsCard(
                      title: 'Thông báo đẩy',
                      subtitle: 'Quản lý việc nhận thông báo từ QuizHub',
                      children: [
                        _SettingSwitch(
                          icon: AppIcons.bellRinging,
                          title: 'Cho phép thông báo',
                          subtitle: 'Bật hoặc tắt tất cả thông báo đẩy',
                          value: settings.pushEnabled,
                          onChanged: (value) => _update(
                            context,
                            settings.copyWith(pushEnabled: value),
                          ),
                        ),
                      ],
                    ),
                    SpacingHelper.vMD,
                    _SettingsCard(
                      title: 'Danh mục thông báo',
                      subtitle: 'Chọn những loại thông báo bạn muốn nhận',
                      children: [
                        if (settings.categories.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Backend hiện chưa cung cấp danh mục thông báo.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        for (final entry in settings.categories.entries)
                          _SettingSwitch(
                            icon: Icons.notifications_none_rounded,
                            title: _formatCategory(entry.key),
                            subtitle: entry.value.description,
                            value: entry.value.enabled,
                            onChanged: (value) => _update(
                              context,
                              settings.updateCategory(entry.key, value),
                            ),
                          ),
                      ],
                    ),
                    SpacingHelper.vMD,
                    _SettingsCard(
                      title: 'Giờ yên tĩnh',
                      subtitle:
                          'Tạm ngưng thông báo trong khoảng thời gian này',
                      children: [
                        _SettingSwitch(
                          icon: AppIcons.moon,
                          title: 'Bật giờ yên tĩnh',
                          subtitle:
                              'Thiết lập khoảng thời gian không làm phiền',
                          value: settings.quietHours.enabled,
                          onChanged: (value) => _update(
                            context,
                            settings.copyWith(
                              quietHours: settings.quietHours.copyWith(
                                enabled: value,
                              ),
                            ),
                          ),
                        ),
                        if (settings.quietHours.enabled) ...[
                          const Divider(
                            height: 1,
                            color: AppColors.borderLight,
                          ),
                          _TimeSetting(
                            title: 'Bắt đầu',
                            value: settings.quietHours.startTime,
                            onTap: () =>
                                _pickTime(context, settings, isStart: true),
                          ),
                          _TimeSetting(
                            title: 'Kết thúc',
                            value: settings.quietHours.endTime,
                            onTap: () =>
                                _pickTime(context, settings, isStart: false),
                          ),
                        ],
                      ],
                    ),
                    SpacingHelper.vMD,
                    _SettingsCard(
                      title: 'Tùy chọn khác',
                      children: [
                        _SettingSwitch(
                          icon: AppIcons.speakerHigh,
                          title: 'Âm thanh',
                          subtitle: 'Phát âm thanh khi có thông báo',
                          value: settings.soundEnabled,
                          onChanged: (value) => _update(
                            context,
                            settings.copyWith(soundEnabled: value),
                          ),
                        ),
                        _SettingSwitch(
                          icon: AppIcons.vibrate,
                          title: 'Rung',
                          subtitle: 'Rung khi nhận được thông báo',
                          value: settings.vibrationEnabled,
                          onChanged: (value) => _update(
                            context,
                            settings.copyWith(vibrationEnabled: value),
                          ),
                        ),
                      ],
                    ),
                    SpacingHelper.vMD,
                    const Center(
                      child: Text(
                        'Các thay đổi chỉ được áp dụng sau khi bạn nhấn Lưu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _SaveBar(
                dirty: state.isDirty,
                saving: state.isSaving,
                onDiscard: () =>
                    context.read<PushSettingsCubit>().discardChanges(),
                onSave: () => context.read<PushSettingsCubit>().save(),
              ),
            ],
          );
        },
      ),
    );
  }

  static void _update(BuildContext context, PushSettings settings) {
    context.read<PushSettingsCubit>().updateDraft(settings);
  }

  static String _formatCategory(String key) {
    final words = key.toLowerCase().replaceAll('_', ' ').split(' ');
    return words
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  static Future<void> _pickTime(
    BuildContext context,
    PushSettings settings, {
    required bool isStart,
  }) async {
    final current = isStart
        ? settings.quietHours.startTime
        : settings.quietHours.endTime;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? (isStart ? 22 : 7),
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) =>
          Theme(data: Theme.of(context), child: child!),
    );
    if (picked == null || !context.mounted) return;

    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final quiet = QuietHours(
      enabled: settings.quietHours.enabled,
      startTime: isStart ? formatted : settings.quietHours.startTime,
      endTime: isStart ? settings.quietHours.endTime : formatted,
    );
    _update(context, settings.copyWith(quietHours: quiet));
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(DesignTokens.spacingMD),
    decoration: BoxDecoration(
      color: AppColors.primary50,
      borderRadius: BorderRadius.circular(ComponentTokens.cardRadius),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(AppIcons.bellRinging, color: AppColors.primary600),
        ),
        SpacingHelper.hMD,
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cá nhân hóa thông báo',
                style: TextStyle(
                  color: AppColors.primary900,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Chọn loại thông báo và thời gian phù hợp với bạn.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SettingsCard({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(ComponentTokens.cardRadius),
      border: Border.all(color: AppColors.borderLight),
    ),
    padding: const EdgeInsets.fromLTRB(
      DesignTokens.spacingMD,
      DesignTokens.spacingMD,
      DesignTokens.spacingSM,
      DesignTokens.spacingSM,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

class _SettingSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    activeThumbColor: AppColors.primary600,
    secondary: Icon(icon, color: AppColors.textSecondary, size: 22),
    title: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: subtitle == null || subtitle!.isEmpty
        ? null
        : Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
    value: value,
    onChanged: onChanged,
  );
}

class _TimeSetting extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _TimeSetting({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.only(left: 38, right: 8),
    title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: AppColors.primary600),
        ),
        const SizedBox(width: 6),
        const Icon(AppIcons.chevronRight, color: AppColors.textTertiary),
      ],
    ),
    onTap: onTap,
  );
}

class _SaveBar extends StatelessWidget {
  final bool dirty;
  final bool saving;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  const _SaveBar({
    required this.dirty,
    required this.saving,
    required this.onDiscard,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      DesignTokens.screenPadding,
      DesignTokens.spacingSM,
      DesignTokens.screenPadding,
      MediaQuery.paddingOf(context).bottom + DesignTokens.spacingSM,
    ),
    decoration: const BoxDecoration(
      color: AppColors.white,
      border: Border(top: BorderSide(color: AppColors.borderLight)),
    ),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: !dirty || saving ? null : onDiscard,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, ComponentTokens.buttonHeight),
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text('Hủy'),
          ),
        ),
        const SizedBox(width: DesignTokens.spacingSM),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: !dirty || saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, ComponentTokens.buttonHeight),
              backgroundColor: AppColors.primary600,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.neutral200,
              disabledForegroundColor: AppColors.textTertiary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  ComponentTokens.buttonRadius,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(DesignTokens.spacingLG),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.offline, size: 42, color: AppColors.textTertiary),
          SpacingHelper.vMD,
          Text(message, textAlign: TextAlign.center),
          SpacingHelper.vMD,
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}
