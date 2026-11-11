import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../storage/token_storage.dart';
import 'firebase_installation_service.dart';

/// Đồng bộ Firebase Installation ID với backend.
///
/// - Khi khởi động: đồng bộ FID hiện tại nếu đã đăng nhập.
/// - Khi FID thay đổi: gửi FID mới lên backend.
/// - Không chặn luồng sử dụng app nếu Firebase hoặc API gặp lỗi.
class FirebaseFidSyncService {
  final ApiClient _api;
  final TokenStorage _tokens;
  final FirebaseInstallationService _installation;

  StreamSubscription<String>? _subscription;

  String? _lastSyncedFid;
  final Set<String> _inFlight = {};

  bool _started = false;

  FirebaseFidSyncService(
    this._api,
    this._tokens,
    this._installation,
  );

  /// Bắt đầu theo dõi FID và đồng bộ FID hiện tại.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _subscription = _installation.onFidChanged.listen(
      (fid) {
        unawaited(syncFid(fid));
      },
      onError: (Object error) {
        debugPrint('[FirebaseFidSync] FID stream error: $error');
      },
    );

    // Không chặn quá trình khởi động ứng dụng.
    unawaited(syncCurrentFid());
  }

  /// Đồng bộ FID hiện tại nếu người dùng đã đăng nhập.
  Future<void> syncCurrentFid() async {
    if (!_tokens.hasTokens) return;

    final fid = await _installation.getFid();
    if (fid == null || fid.isEmpty) return;

    await syncFid(fid);
  }

  /// Gửi FID mới lên backend.
  Future<void> syncFid(String fid) async {
    if (!_tokens.hasTokens || fid.isEmpty) return;
    if (fid == _lastSyncedFid || _inFlight.contains(fid)) return;

    _inFlight.add(fid);

    try {
      await _api.postVoid(
        ApiEndpoints.deviceFid,
        body: {'fid': fid},
      );

      _lastSyncedFid = fid;
      debugPrint('[FirebaseFidSync] FID synchronized successfully');
    } catch (error, stackTrace) {
      // Không chặn ứng dụng. Lần khởi động tiếp theo có thể thử lại.
      debugPrint('[FirebaseFidSync] Cannot synchronize FID: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _inFlight.remove(fid);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}