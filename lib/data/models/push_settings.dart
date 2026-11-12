import '../../core/utils/json_utils.dart';

/// Cấu hình thông báo đẩy. Category là Map động vì backend có thể bổ sung key.
class PushSettings {
  final bool pushEnabled;
  final Map<String, PushCategory> categories;
  final QuietHours quietHours;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const PushSettings({
    required this.pushEnabled,
    required this.categories,
    required this.quietHours,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  factory PushSettings.fromJson(Map<String, dynamic> json) {
    final rawCategories = J.asMap(json['categories']) ?? const {};
    return PushSettings(
      pushEnabled: J.asBool(json['push_enabled']),
      categories: rawCategories.map((key, value) {
        final categoryJson = J.asMap(value) ?? const <String, dynamic>{};
        return MapEntry(key, PushCategory.fromJson(categoryJson));
      }),
      quietHours: QuietHours.fromJson(J.asMap(json['quiet_hours']) ?? const {}),
      soundEnabled: J.asBool(json['sound_enabled']),
      vibrationEnabled: J.asBool(json['vibration_enabled']),
    );
  }

  Map<String, dynamic> toJson() => {
    'push_enabled': pushEnabled,
    'categories': categories.map((key, value) => MapEntry(key, value.toJson())),
    'quiet_hours': quietHours.toJson(),
    'sound_enabled': soundEnabled,
    'vibration_enabled': vibrationEnabled,
  };

  PushSettings copyWith({
    bool? pushEnabled,
    Map<String, PushCategory>? categories,
    QuietHours? quietHours,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) => PushSettings(
    pushEnabled: pushEnabled ?? this.pushEnabled,
    categories: categories ?? this.categories,
    quietHours: quietHours ?? this.quietHours,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
  );

  PushSettings updateCategory(String key, bool enabled) {
    final updated = Map<String, PushCategory>.from(categories);
    final category = updated[key];
    if (category != null) {
      updated[key] = category.copyWith(enabled: enabled);
    }
    return copyWith(categories: updated);
  }
}

class PushCategory {
  final bool enabled;
  final String description;

  const PushCategory({required this.enabled, this.description = ''});

  factory PushCategory.fromJson(Map<String, dynamic> json) => PushCategory(
    enabled: J.asBool(json['enabled']),
    description: J.stringOr(json['description']),
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'description': description,
  };

  PushCategory copyWith({bool? enabled, String? description}) => PushCategory(
    enabled: enabled ?? this.enabled,
    description: description ?? this.description,
  );
}

class QuietHours {
  final bool enabled;
  final String startTime;
  final String endTime;

  const QuietHours({
    this.enabled = false,
    this.startTime = '22:00',
    this.endTime = '07:00',
  });

  factory QuietHours.fromJson(Map<String, dynamic> json) => QuietHours(
    enabled: J.asBool(json['enabled']),
    startTime: J.stringOr(json['start_time'], '22:00'),
    endTime: J.stringOr(json['end_time'], '07:00'),
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'start_time': startTime,
    'end_time': endTime,
  };

  QuietHours copyWith({bool? enabled, String? startTime, String? endTime}) =>
      QuietHours(
        enabled: enabled ?? this.enabled,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
      );
}
