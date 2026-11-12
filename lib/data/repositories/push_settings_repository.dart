import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/push_settings.dart';

class PushSettingsRepository {
  final ApiClient _api;

  PushSettingsRepository(this._api);

  Future<PushSettings> getSettings() => _api.get<PushSettings>(
    ApiEndpoints.pushSettings,
    parser: (data) => PushSettings.fromJson(J.asMap(data) ?? const {}),
  );

  Future<PushSettings> updateSettings(PushSettings settings) =>
      _api.put<PushSettings>(
        ApiEndpoints.pushSettings,
        body: settings.toJson(),
        parser: (data) => PushSettings.fromJson(J.asMap(data) ?? const {}),
      );
}
