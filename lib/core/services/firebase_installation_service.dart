import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:flutter/foundation.dart';

class FirebaseInstallationService {
  Future<String?> getFid() async {
    try {
      final fid = await FirebaseInstallations.instance.getId();

      if (fid.isEmpty) return null;

      debugPrint('[Firebase] FID: $fid');
      return fid;
    } catch (error, stackTrace) {
      debugPrint('[Firebase] Cannot get FID: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Phát sự kiện khi Firebase Installation ID thay đổi.
  Stream<String> get onFidChanged =>
      FirebaseInstallations.instance.onIdChange;
}
