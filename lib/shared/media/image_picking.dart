import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/app_feedback.dart';
import '../../data/models/media_item.dart';
import '../../data/repositories/media_repository.dart';
import '../../di/locator.dart';
import '../../core/design_system/app_icons.dart';

/// Dùng XFile để ảnh chọn từ web cũng đọc được như ảnh trên điện thoại.
Future<XFile?> _pickImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(AppIcons.camera),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(AppIcons.photos),
            title: const Text('Chọn từ thư viện'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;

  try {
    // Nén nhẹ để ảnh gần như luôn < 4MB
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    return picked;
  } catch (_) {
    if (context.mounted) {
      AppFeedback.errorMessage(
        context,
        'Không thể truy cập ảnh. Hãy kiểm tra quyền Camera / Thư viện.',
      );
    }
    return null;
  }
}

/// Chọn ảnh + upload lên server (có loading overlay). Trả về null nếu huỷ/lỗi.
Future<MediaUploadResult?> pickAndUploadImage(
  BuildContext context, {
  required MediaPurpose purpose,
}) async {
  final file = await _pickImage(context);
  if (file == null || !context.mounted) return null;
  try {
    return await AppFeedback.withLoading(
      () async => getIt<MediaRepository>().uploadImageBytes(
        await file.readAsBytes(),
        name: file.name,
        purpose: purpose,
      ),
    );
  } on ApiException catch (e) {
    if (context.mounted) AppFeedback.error(context, e);
    return null;
  }
}
