import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/component_tokens.dart';
import '../../core/network/api_exception.dart';
import '../../core/services/post_events.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/media_item.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/post_repository.dart';
import '../../di/locator.dart';
import '../profile/cubit/profile_cubit.dart';
import '../../core/design_system/app_icons.dart';

/// Màn "Tạo bài viết" kiểu Facebook: avatar + tên + chọn quyền riêng tư,
/// ô nhập nội dung, ảnh đính kèm, thanh công cụ phía dưới.
///
/// Đóng màn bằng `pop(PostModel)` khi đăng thành công (đồng thời phát
/// [PostEvents.onPublished] để Bảng tin / Trang cá nhân tự chèn bài mới).
class CreatePostView extends StatefulWidget {
  /// Mở ngay thư viện ảnh khi vào màn (bấm icon ảnh ở thanh composer).
  final bool pickImagesOnOpen;
  final PostModel? initialPost;

  const CreatePostView({
    super.key,
    this.pickImagesOnOpen = false,
    this.initialPost,
  });

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final List<File> _images = [];
  final List<MediaItem> _existingMedia = [];
  PostVisibility _visibility = PostVisibility.public;
  bool _posting = false;

  bool get _isEditing => widget.initialPost != null;

  @override
  void initState() {
    super.initState();
    final post = widget.initialPost;
    if (post != null) {
      _text.text = post.content;
      _visibility = post.visibility;
      _existingMedia.addAll(post.media);
    }
    _text.addListener(() => setState(() {}));
    if (widget.pickImagesOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickFromGallery());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _dirty {
    final original = widget.initialPost;
    if (original == null) {
      return _text.text.trim().isNotEmpty || _images.isNotEmpty;
    }
    return _text.text != original.content ||
        _visibility != original.visibility ||
        _images.isNotEmpty ||
        !_sameMedia(_existingMedia, original.media);
  }

  static bool _sameMedia(List<MediaItem> a, List<MediaItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int get _imageCount =>
      _existingMedia.where((media) => media.isImage).length + _images.length;

  int get _words => Validators.wordCount(_text.text);
  bool get _tooLong => _words > ComponentTokens.maxPostWords;
  bool get _canPost =>
      _dirty &&
      (_text.text.trim().isNotEmpty ||
          _existingMedia.isNotEmpty ||
          _images.isNotEmpty) &&
      !_tooLong &&
      !_posting;

  // ---------------- Ảnh ----------------
  Future<void> _pickFromGallery() async {
    final remaining = ComponentTokens.maxImagesPerPost - _imageCount;
    if (remaining <= 0) {
      AppFeedback.info(
        context,
        'Mỗi bài viết tối đa ${ComponentTokens.maxImagesPerPost} ảnh.',
      );
      return;
    }
    try {
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _images.addAll(picked.take(remaining).map((x) => File(x.path)));
      });
      if (picked.length > remaining && mounted) {
        AppFeedback.info(
          context,
          'Chỉ thêm được ${ComponentTokens.maxImagesPerPost} ảnh mỗi bài.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.errorMessage(
          context,
          'Không thể truy cập ảnh. Hãy kiểm tra quyền Thư viện.',
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    if (_imageCount >= ComponentTokens.maxImagesPerPost) {
      AppFeedback.info(
        context,
        'Mỗi bài viết tối đa ${ComponentTokens.maxImagesPerPost} ảnh.',
      );
      return;
    }
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (shot == null || !mounted) return;
      setState(() => _images.add(File(shot.path)));
    } catch (_) {
      if (mounted) {
        AppFeedback.errorMessage(
          context,
          'Không thể mở máy ảnh. Hãy kiểm tra quyền Camera.',
        );
      }
    }
  }

  // ---------------- Quyền riêng tư ----------------
  Future<void> _chooseVisibility() async {
    _focus.unfocus();
    final picked = await showModalBottomSheet<PostVisibility>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Ai có thể xem bài viết của bạn?',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final v in PostVisibility.values)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.chip,
                  child: Icon(_visIcon(v), color: AppColors.textPrimary),
                ),
                title: Text(v.label),
                subtitle: Text(_visHint(v)),
                trailing: Icon(
                  v == _visibility ? AppIcons.radioOn : AppIcons.radioOff,
                  color: v == _visibility
                      ? AppColors.primary600
                      : AppColors.textSecondary,
                ),
                onTap: () => Navigator.pop(ctx, v),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _visibility = picked);
  }

  static IconData _visIcon(PostVisibility v) => switch (v) {
    PostVisibility.public => AppIcons.audienceEveryone,
    PostVisibility.friends => AppIcons.audienceFriends,
    PostVisibility.onlyMe => AppIcons.audienceOnlyMe,
  };

  static String _visHint(PostVisibility v) => switch (v) {
    PostVisibility.public => 'Bất kỳ ai trên QuizHub',
    PostVisibility.friends => 'Bạn bè của bạn',
    PostVisibility.onlyMe => 'Chỉ bạn xem được',
  };

  // ---------------- Đăng ----------------
  Future<void> _submit() async {
    if (!_canPost) return;
    _focus.unfocus();
    setState(() => _posting = true);
    try {
      final saved = await AppFeedback.withLoading(() async {
        final media = List<MediaItem>.of(_existingMedia);
        for (final f in _images) {
          final up = await getIt<MediaRepository>().uploadImage(
            f,
            purpose: MediaPurpose.post,
          );
          media.add(up.toMediaItem());
        }
        final repo = getIt<PostRepository>();
        final original = widget.initialPost;
        if (original != null) {
          await repo.update(
            original.postId,
            content: _text.text.trim(),
            media: media,
            visibility: _visibility,
          );
          try {
            return await repo.getById(original.postId);
          } on ApiException {
            return original.copyWith(
              content: _text.text.trim(),
              media: media,
              visibility: _visibility,
              updatedAt: DateTime.now(),
            );
          }
        }
        final post = await repo.create(
          content: _text.text.trim(),
          media: media,
          visibility: _visibility,
        );
        // Lấy lại bản đầy đủ (có tác giả) để hiển thị đúng ngay trên feed
        try {
          return await repo.getById(post.postId);
        } on ApiException {
          return post;
        }
      });
      if (!mounted) return;
      if (_isEditing) {
        getIt<PostEvents>().update(saved);
      } else {
        getIt<PostEvents>().publish(saved);
      }
      AppFeedback.success(
        context,
        _isEditing ? 'Đã lưu thay đổi' : 'Đã đăng bài viết',
      );
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _posting = false);
        AppFeedback.error(context, e);
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_posting) return false;
    if (!_dirty) return true;
    final ok = await showConfirmDialog(
      context,
      title: _isEditing ? 'Bỏ thay đổi?' : 'Bỏ bài viết?',
      message: _isEditing
          ? 'Các thay đổi bạn vừa thực hiện sẽ bị mất.'
          : 'Nội dung bạn đã nhập sẽ bị mất.',
      confirmLabel: _isEditing ? 'Bỏ thay đổi' : 'Bỏ bài viết',
      cancelLabel: 'Tiếp tục viết',
      destructive: true,
    );
    return ok;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = context.watch<ProfileCubit>().state.profile;
    final short = _text.text.length < 120 && _imageCount == 0;

    return PopScope(
      canPop: !_dirty && !_posting,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(AppIcons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_isEditing ? 'Chỉnh sửa bài viết' : 'Tạo bài viết'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _canPost ? _submit : null,
                style: TextButton.styleFrom(
                  backgroundColor: _canPost
                      ? AppColors.primary600
                      : AppColors.chip,
                  foregroundColor: _canPost
                      ? AppColors.white
                      : AppColors.textTertiary,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  minimumSize: const Size(0, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(_isEditing ? 'LƯU' : 'ĐĂNG'),
              ),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        avatarUrl: me?.avatarUrl,
                        frameUrl: me?.frameUrl,
                        name: me?.fullName ?? '',
                        size: 44,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (me?.fullName ?? '').isEmpty
                                  ? 'Bạn'
                                  : me!.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _VisibilityChip(
                              visibility: _visibility,
                              onTap: _chooseVisibility,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _text,
                    focusNode: _focus,
                    autofocus: !widget.pickImagesOnOpen,
                    minLines: short ? 6 : 3,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: short ? 22 : 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Bạn đang nghĩ gì?',
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: short ? 22 : 16,
                        color: AppColors.textTertiary,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  if (_tooLong)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Bài viết tối đa ${ComponentTokens.maxPostWords} từ '
                        '(hiện $_words từ).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  if (_existingMedia.isNotEmpty || _images.isNotEmpty)
                    _ImagePreviews(
                      media: _existingMedia,
                      images: _images,
                      onRemoveExisting: (i) =>
                          setState(() => _existingMedia.removeAt(i)),
                      onRemoveImage: (i) => setState(() => _images.removeAt(i)),
                    ),
                ],
              ),
            ),
            _Toolbar(
              onGallery: _pickFromGallery,
              onCamera: _takePhoto,
              imageCount: _imageCount,
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final PostVisibility visibility;
  final VoidCallback onTap;

  const _VisibilityChip({required this.visibility, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _CreatePostViewState._visIcon(visibility),
              size: 16,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              visibility.label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Icon(AppIcons.dropdown, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviews extends StatelessWidget {
  final List<MediaItem> media;
  final List<File> images;
  final ValueChanged<int> onRemoveExisting;
  final ValueChanged<int> onRemoveImage;

  const _ImagePreviews({
    required this.media,
    required this.images,
    required this.onRemoveExisting,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    final count = media.length + images.length;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count == 1 ? 1 : 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: count == 1 ? 1.4 : 1,
      ),
      itemBuilder: (context, i) {
        final isExisting = i < media.length;
        final item = isExisting ? media[i] : null;
        final Widget preview;
        if (item == null) {
          preview = Image.file(images[i - media.length], fit: BoxFit.cover);
        } else if (item.isImage) {
          preview = Image.network(
            item.url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const _MediaPlaceholder(icon: AppIcons.imageBroken),
          );
        } else {
          preview = _MediaPlaceholder(
            icon: item.isVideo ? AppIcons.playCircle : AppIcons.article,
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              preview,
              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: () => isExisting
                      ? onRemoveExisting(i)
                      : onRemoveImage(i - media.length),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xAA000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.close,
                      size: 20,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final IconData icon;

  const _MediaPlaceholder({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.chip,
    child: Icon(icon, size: 40, color: AppColors.textSecondary),
  );
}

class _Toolbar extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final int imageCount;

  const _Toolbar({
    required this.onGallery,
    required this.onCamera,
    required this.imageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      padding: EdgeInsets.fromLTRB(
        8,
        4,
        8,
        4 + MediaQuery.paddingOf(context).bottom * 0.5,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Ảnh',
            iconSize: 30,
            icon: const Icon(AppIcons.photosFill, color: AppColors.success),
            onPressed: onGallery,
          ),
          IconButton(
            tooltip: 'Chụp ảnh',
            iconSize: 30,
            icon: const Icon(AppIcons.cameraFill, color: AppColors.info),
            onPressed: onCamera,
          ),
          const Spacer(),
          Text(
            '$imageCount/${ComponentTokens.maxImagesPerPost} ảnh',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
