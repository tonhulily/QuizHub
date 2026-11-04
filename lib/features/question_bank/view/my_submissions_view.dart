import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/session_models.dart';
import '../../../data/repositories/submission_repository.dart';
import '../../../di/locator.dart';
import '../widgets/qbank_widgets.dart';

/// "Phiên của tôi": các phiên mình đã đề xuất, chia tab theo trạng thái.
///
/// Danh sách của backend không trả `status` cho từng phiên, chỉ cho lọc theo
/// trạng thái; vì vậy mỗi tab tự biết trạng thái của các phiên trong nó.
class MySubmissionsView extends StatefulWidget {
  const MySubmissionsView({super.key});

  @override
  State<MySubmissionsView> createState() => _MySubmissionsViewState();
}

class _MySubmissionsViewState extends State<MySubmissionsView>
    with SingleTickerProviderStateMixin {
  /// null = tab "Tất cả"
  static const List<SessionStatus?> _statuses = [
    null,
    ...SessionStatus.filters,
  ];

  late final List<PagedCubit<SubmissionSummary>> _cubits = [
    for (final status in _statuses)
      PagedCubit<SubmissionSummary>(
        (after) => getIt<SubmissionRepository>().mySubmissions(
          after: after,
          status: status,
        ),
      ),
  ];

  late final TabController _tabs = TabController(
    length: _statuses.length,
    vsync: this,
  )..addListener(_onTab);

  @override
  void initState() {
    super.initState();
    _cubits.first.load();
  }

  /// Tab chỉ tải khi mở lần đầu.
  void _onTab() {
    final c = _cubits[_tabs.index];
    if (c.state.status == PagedStatus.initial) c.load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _cubits) {
      c.close();
    }
    super.dispose();
  }

  /// Sau khi tạo / sửa / xoá thì mọi tab đều có thể đã đổi.
  void _reloadAll() {
    for (final c in _cubits) {
      if (c.state.status != PagedStatus.initial) c.refresh();
    }
  }

  Future<void> _create() async {
    final saved = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.qbankSubmissionForm);
    if (saved != true || !mounted) return;
    AppFeedback.success(context, 'Đã gửi phiên đề xuất, chờ giảng viên duyệt.');
    _reloadAll();
  }

  Future<void> _open(SubmissionSummary s, SessionStatus? tab) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.qbankSubmission,
      arguments: (id: s.sessionId, status: tab ?? s.status),
    );
    if (mounted) _reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('Phiên của tôi'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary600,
          indicatorColor: AppColors.primary600,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [for (final s in _statuses) Tab(text: s?.label ?? 'Tất cả')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primary600,
        foregroundColor: AppColors.white,
        icon: const Icon(AppIcons.add),
        label: const Text('Đề xuất'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (var i = 0; i < _statuses.length; i++)
            BlocProvider.value(
              value: _cubits[i],
              child: PagedListView<SubmissionSummary>(
                padding: const EdgeInsets.only(bottom: 88),
                itemSpacing: ComponentTokens.postGap,
                emptyView: EmptyView(
                  icon: AppIcons.inbox,
                  title: _statuses[i] == null
                      ? 'Bạn chưa đề xuất phiên nào'
                      : 'Không có phiên "${_statuses[i]!.label}"',
                  message: _statuses[i] == null
                      ? 'Bấm "Đề xuất" để gửi bộ câu hỏi đầu tiên.'
                      : null,
                ),
                itemBuilder: (context, s) => SessionTile(
                  session: s,
                  showStatus: _statuses[i] == null,
                  onTap: () => _open(s, _statuses[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
