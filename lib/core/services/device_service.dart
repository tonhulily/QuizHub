import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../storage/local_storage.dart';

/// Thông tin thiết bị gửi kèm khi đăng nhập.
class DeviceInfo {
  final String deviceId;
  final String platform; // IOS | ANDROID
  final String deviceName;
  final String osVersion;
  final String appVersion;

  const DeviceInfo({
    required this.deviceId,
    required this.platform,
    required this.deviceName,
    required this.osVersion,
    required this.appVersion,
  });
}

/// Sinh & lưu `device_id` bền vững (UUID) + đọc thông tin máy.
class DeviceService {
  final LocalStorage _storage;
  DeviceInfo? _cached;

  DeviceService(this._storage);

  Future<DeviceInfo> getInfo() async {
    if (_cached != null) return _cached!;

    var deviceId = _storage.deviceId;
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await _storage.setDeviceId(deviceId);
    }

    var name = 'Unknown device';
    var os = '';
    var appVersion = '';
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        name = '${a.manufacturer} ${a.model}'.trim();
        os = 'Android ${a.version.release}';
      } else if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        name = i.name;
        os = '${i.systemName} ${i.systemVersion}';
      }
      final pkg = await PackageInfo.fromPlatform();
      appVersion = pkg.version;
    } catch (e) {
      debugPrint('[DeviceService] cannot read device info: $e');
    }

    return _cached = DeviceInfo(
      deviceId: deviceId,
      platform: Platform.isIOS ? 'IOS' : 'ANDROID',
      deviceName: name,
      osVersion: os,
      appVersion: appVersion,
    );
  }
}
