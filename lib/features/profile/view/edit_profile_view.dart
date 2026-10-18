import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_navigator.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/media_repository.dart';
import '../../../shared/media/image_picking.dart';
import '../cubit/profile_cubit.dart';
import '../widgets/info_grid.dart';
import '../../../core/design_system/app_icons.dart';

/// Chỉnh sửa hồ sơ. [forceComplete] = true khi tài khoản mới đăng nhập lần đầu:
/// bắt buộc có tên + ảnh đại diện, không cho quay lại.
class EditProfileView extends StatefulWidget {
  final bool forceComplete;

  const EditProfileView({super.key, this.forceComplete = false});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;

  String? _avatarUrl;
  String? _coverUrl;

  /// Ảnh lúc mở màn hình: chỉ gửi lên server ảnh nào thực sự đổi / gỡ.
  String? _origAvatar;
  String? _origCover;
  Gender? _gender;
  DateTime? _dob;
  bool _saving = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileCubit>().state.profile;
    _nameCtrl = TextEditingController(text: p?.fullName ?? '');
    _bioCtrl = TextEditingController(text: p?.bio ?? '');
    _avatarUrl = p?.avatarUrl;
    _coverUrl = p?.coverUrl;
    _origAvatar = p?.avatarUrl;
    _origCover = p?.coverUrl;
    _gender = p?.gender;
    _dob = p?.dateOfBirth;
    _initialised = p != null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(MediaPurpose purpose) async {
    final result = await pickAndUploadImage(context, purpose: purpose);
    if (result == null || !mounted) return;
    setState(() {
      if (purpose == MediaPurpose.avatar) {
        _avatarUrl = result.url;
      } else {
        _coverUrl = result.url;
      }
    });
  }

  /// Gỡ ảnh hiện tại -> trở về ảnh mặc định (chữ cái đầu / nền màu thương hiệu).
  /// Chỉ áp dụng khi bấm "Lưu thay đổi".
  void _removePhoto(MediaPurpose purpose) {
    setState(() {
      if (purpose == MediaPurpose.avatar) {
        _avatarUrl = '';
      } else {
        _coverUrl = '';
      }
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'Chọn ngày sinh',
      cancelText: 'Huỷ',
      confirmText: 'Chọn',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (widget.forceComplete && (_avatarUrl ?? '').isEmpty) {
      AppFeedback.errorMessage(context, 'Vui lòng chọn ảnh đại diện.');
      return;
    }

    final avatarChanged = (_avatarUrl ?? '') != (_origAvatar ?? '');
    final coverChanged = (_coverUrl ?? '') != (_origCover ?? '');

    setState(() => _saving = true);
    try {
      final updated = await context.read<ProfileCubit>().update(
        fullName: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        // '' = gỡ ảnh; null = không đổi (không gửi lên)
        avatarUrl: avatarChanged ? (_avatarUrl ?? '') : null,
        coverUrl: coverChanged ? (_coverUrl ?? '') : null,
        gender: _gender,
        dateOfBirth: _dob,
      );
      if (!mounted) return;

      // Server có thể bỏ qua chuỗi rỗng: báo rõ thay vì im lặng.
      final avatarStuck =
          avatarChanged &&
          (_avatarUrl ?? '').isEmpty &&
          (updated.avatarUrl ?? '').isNotEmpty;
      final coverStuck =
          coverChanged &&
          (_coverUrl ?? '').isEmpty &&
          (updated.coverUrl ?? '').isNotEmpty;
      if (avatarStuck || coverStuck) {
        setState(() {
          _saving = false;
          if (avatarStuck) _avatarUrl = updated.avatarUrl;
          if (coverStuck) _coverUrl = updated.coverUrl;
          _origAvatar = updated.avatarUrl;
          _origCover = updated.coverUrl;
        });
        final what = avatarStuck && coverStuck
            ? 'ảnh đại diện và ảnh bìa'
            : (avatarStuck ? 'ảnh đại diện' : 'ảnh bìa');
        AppFeedback.errorMessage(
          context,
          'Máy chủ chưa cho phép gỡ $what. Các thay đổi khác đã được lưu.',
        );
        return;
      }
      AppFeedback.success(context, 'Đã cập nhật hồ sơ');
      if (widget.forceComplete) {
        AppNavigator.toMain();
      } else {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !widget.forceComplete,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.forceComplete ? 'Hoàn thiện hồ sơ' : 'Chỉnh sửa hồ sơ',
          ),
          automaticallyImplyLeading: !widget.forceComplete,
        ),
        body: !_initialised
            ? const Center(child: Text('Không tải được hồ sơ'))
            : GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildImages(),
                    Padding(
                      padding: const EdgeInsets.all(DesignTokens.screenPadding),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.forceComplete)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.infoLight,
                                  borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusMD,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      AppIcons.infoOutline,
                                      color: AppColors.infoDark,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Hãy đặt tên hiển thị và ảnh đại diện để bắt đầu sử dụng QuizHub.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: AppColors.infoDark,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const _FieldLabel('Họ và tên', public: true),
                            const SizedBox(height: 8),
                            AppTextField(
                              controller: _nameCtrl,
                              hint: 'Nguyễn Văn A',
                              prefixIcon: AppIcons.person,
                              textInputAction: TextInputAction.next,
                              maxLength: 100,
                              validator: Validators.fullName,
                            ),
                            const SizedBox(height: 16),
                            const _FieldLabel('Tiểu sử', public: true),
                            const SizedBox(height: 8),
                            AppTextField(
                              controller: _bioCtrl,
                              hint: 'Giới thiệu đôi chút về bạn...',
                              maxLines: 4,
                              maxLength: 500,
                              keyboardType: TextInputType.multiline,
                              validator: Validators.bio,
                            ),
                            const SizedBox(height: 16),
                            const _FieldLabel('Giới tính', public: true),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (final g in Gender.values) ...[
                                  ChoiceChip(
                                    label: Text(g.label),
                                    selected: _gender == g,
                                    selectedColor: AppColors.primary100,
                                    labelStyle: TextStyle(
                                      color: _gender == g
                                          ? AppColors.primary800
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    side: BorderSide(
                                      color: _gender == g
                                          ? AppColors.primary400
                                          : AppColors.border,
                                    ),
                                    showCheckmark: false,
                                    onSelected: (_) =>
                                        setState(() => _gender = g),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            const _FieldLabel('Ngày sinh', public: false),
                            const SizedBox(height: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(
                                ComponentTokens.inputRadius,
                              ),
                              onTap: _pickDob,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(AppIcons.birthday, size: 20),
                                ),
                                child: Text(
                                  _dob == null
                                      ? 'Chọn ngày sinh'
                                      : TimeFormat.date(_dob),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: _dob == null
                                        ? AppColors.textTertiary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ngày sinh chỉ mình bạn nhìn thấy, người khác không xem được.',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 28),
                            AppButton(
                              label: widget.forceComplete
                                  ? 'Hoàn tất'
                                  : 'Lưu thay đổi',
                              loading: _saving,
                              onPressed: _save,
                            ),
                            if (!widget.forceComplete) ...[
                              const SizedBox(height: 28),
                              _ReadOnlySections(
                                profile: context
                                    .read<ProfileCubit>()
                                    .state
                                    .profile!,
                              ),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildImages() {
    const coverHeight = 150.0;
    const avatarSize = ComponentTokens.avatarXL;
    final name = _nameCtrl.text;

    return SizedBox(
      height: coverHeight + avatarSize / 2 + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: coverHeight,
            child: GestureDetector(
              onTap: () => _pick(MediaPurpose.cover),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if ((_coverUrl ?? '').isEmpty)
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: _coverUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  Container(color: const Color(0x33000000)),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _PhotoBadge(label: 'Đổi ảnh bìa'),
                        if ((_coverUrl ?? '').isNotEmpty) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _removePhoto(MediaPurpose.cover),
                            child: const Tooltip(
                              message: 'Gỡ ảnh bìa',
                              child: _PhotoBadge(
                                label: 'Gỡ ảnh bìa',
                                icon: AppIcons.delete,
                                danger: true,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _pick(MediaPurpose.avatar),
                child: Stack(
                  children: [
                    UserAvatar(
                      avatarUrl: _avatarUrl,
                      name: name,
                      size: avatarSize,
                      showBorder: true,
                    ),
                    if ((_avatarUrl ?? '').isNotEmpty)
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => _removePhoto(MediaPurpose.avatar),
                          child: Tooltip(
                            message: 'Gỡ ảnh đại diện',
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                AppIcons.delete,
                                size: 16,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                        child: const Icon(
                          AppIcons.cameraFill,
                          size: 16,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool danger;

  const _PhotoBadge({
    required this.label,
    this.icon = AppIcons.camera,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: danger ? const Color(0xCCEF4444) : const Color(0x80000000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn của một mục + thẻ cho biết ai xem được mục đó.
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool public;

  const _FieldLabel(this.text, {required this.public});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.labelLarge),
        ),
        _VisibilityTag(public: public),
      ],
    );
  }
}

/// "Mọi người" / "Chỉ mình bạn" - phản ánh đúng cách server đang hiển thị
/// (cố định, chưa cho người dùng tuỳ chỉnh).
class _VisibilityTag extends StatelessWidget {
  final bool public;
  const _VisibilityTag({required this.public});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: public ? AppColors.backgroundSecondary : AppColors.warningLight,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            public ? AppIcons.audienceEveryone : AppIcons.audienceOnlyMe,
            size: 14,
            color: public ? AppColors.textSecondary : AppColors.warningDark,
          ),
          const SizedBox(width: 4),
          Text(
            public ? 'Mọi người' : 'Chỉ mình bạn',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: public ? AppColors.textSecondary : AppColors.warningDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Các thông tin đang hiện trên trang cá nhân nhưng KHÔNG sửa được ở đây
/// (do nhà trường cấp hoặc hệ thống tự tính), kèm ai xem được từng mục.
class _ReadOnlySections extends StatelessWidget {
  final ProfileModel profile;
  const _ReadOnlySections({required this.profile});

  static bool _has(String? v) => (v ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final theme = Theme.of(context);
    final points = p.gamificationPoints % 1 == 0
        ? p.gamificationPoints.toInt().toString()
        : p.gamificationPoints.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        _InfoSection(
          title: 'Thông tin từ nhà trường',
          subtitle: 'Do nhà trường cấp, bạn không thể tự sửa.',
          rows: [
            if (_has(p.studentLecturerCode))
              _InfoRow(
                AppIcons.idCard,
                'Mã số SV/GV',
                p.studentLecturerCode!,
                public: true,
              ),
            if (_has(p.schoolFaculty))
              _InfoRow(
                AppIcons.faculty,
                'Khoa / Viện',
                p.schoolFaculty!,
                public: true,
              ),
            if (_has(p.major))
              _InfoRow(AppIcons.school, 'Chuyên ngành', p.major!, public: true),
            if (_has(p.className))
              _InfoRow(AppIcons.classGroup, 'Lớp', p.className!, public: true),
            _InfoRow(AppIcons.lecturer, 'Vai trò', p.role.label, public: true),
          ],
        ),
        _InfoSection(
          title: 'Tài khoản',
          rows: [
            if (_has(p.email))
              _InfoRow(AppIcons.emailAddress, 'Email', p.email!, public: false),
            if (p.createdAt != null)
              _InfoRow(
                AppIcons.joined,
                'Ngày tham gia',
                TimeFormat.date(p.createdAt),
                public: true,
              ),
          ],
        ),
        _InfoSection(
          title: 'Hoạt động',
          subtitle: 'Hệ thống tự tính, không thể chỉnh sửa.',
          rows: [
            _InfoRow(AppIcons.points, 'Điểm tích luỹ', points, public: true),
            _InfoRow(
              AppIcons.quizActive,
              'Câu hỏi đã đề xuất',
              '${p.totalProposedQuestions}',
              public: true,
            ),
            _InfoRow(
              AppIcons.badge,
              'Huy hiệu',
              '${p.badgesCount}',
              public: true,
            ),
            _InfoRow(
              AppIcons.friends,
              'Bạn bè',
              '${p.friendsCount}',
              public: true,
            ),
            _InfoRow(
              AppIcons.person,
              'Người theo dõi',
              '${p.followersCount}',
              public: true,
            ),
            _InfoRow(
              AppIcons.person,
              'Đang theo dõi',
              '${p.followingCount}',
              public: true,
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(AppIcons.infoOutline, color: AppColors.infoDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Máy chủ chỉ trả ngày sinh và email cho chính bạn, người khác không '
                  'xem được. Hiện chưa có tuỳ chọn ẩn/hiện riêng từng mục hồ sơ vì '
                  'máy chủ chưa hỗ trợ. Quyền xem của bài viết (Công khai / Bạn bè / '
                  'Chỉ mình tôi) bạn chọn khi đăng bài.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.infoDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<_InfoRow> rows;

  const _InfoSection({required this.title, this.subtitle, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 10),
          // Lưới 2 cột thay cho danh sách dọc
          InfoGrid(items: [for (final r in rows) r.toItem()]),
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final bool public;

  const _InfoRow(this.icon, this.label, this.value, {required this.public});

  InfoItem toItem() => InfoItem(
    icon: icon,
    label: label,
    value: value,
    color: public ? AppColors.primary600 : AppColors.warningDark,
    audience: public ? InfoAudience.everyone : InfoAudience.onlyMe,
  );
}
