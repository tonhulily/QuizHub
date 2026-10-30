import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/auth_session.dart';
import '../../../data/models/session_models.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/question_bank_repository.dart';
import '../../../data/repositories/subject_repository.dart';
import '../../../di/locator.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../cubit/load_cubit.dart';
import '../widgets/qbank_widgets.dart';

/// Tab "Ngân hàng đề": lối tắt, tìm phiên đã duyệt theo từ khoá / môn, và
/// danh sách phiên để luyện tập.
///
/// Backend chưa có API liệt kê phiên theo môn (API_CONTRACT mục 6.1) nên
/// danh sách dựa trên `/search?type=SESSION`; chọn môn = tìm theo mã môn.
class QuestionBankTab extends StatefulWidget {
  const QuestionBankTab({super.key});

  @override
  State<QuestionBankTab> createState() => _QuestionBankTabState();
}

class _QuestionBankTabState extends State<QuestionBankTab> {
  final _search = TextEditingController();
  String _query = '';

  late final PagedCubit<SubmissionSummary> _sessions = PagedCubit(
    (after) =>
        getIt<QuestionBankRepository>().searchSessions(_query, after: after),
  )..load();

  late final LoadCubit<List<SubjectModel>> _subjects = LoadCubit(
    () => getIt<SubjectRepository>().enrolled(),
  )..load();

  @override
  void dispose() {
    _search.dispose();
    _sessions.close();
    _subjects.close();
    super.dispose();
  }

  void _runSearch(String q) {
    final next = q.trim();
    if (next == _query) return;
    setState(() => _query = next);
    _sessions.load();
  }

  void _pickSubject(SubjectModel s) {
    final next = _query == s.code ? '' : s.code;
    _search.text = next;
    _runSearch(next);
  }

  Future<void> _propose() async {
    final saved = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.qbankSubmissionForm);
    if (saved == true && mounted) {
      AppFeedback.success(
        context,
        'Đã gửi phiên đề xuất, chờ giảng viên duyệt.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.select<ProfileCubit, UserRole?>(
      (c) => c.state.profile?.role,
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _sessions),
        BlocProvider.value(value: _subjects),
      ],
      child: PagedListView<SubmissionSummary>(
        padding: EdgeInsets.zero,
        itemSpacing: ComponentTokens.postGap,
        header: _Header(
          search: _search,
          query: _query,
          isLecturer: role == UserRole.lecturer,
          onSearch: _runSearch,
          onPickSubject: _pickSubject,
          onPropose: _propose,
        ),
        emptyView: EmptyView(
          icon: AppIcons.quizActive,
          title: _query.isEmpty
              ? 'Chưa có phiên câu hỏi nào'
              : 'Không tìm thấy phiên phù hợp',
          message: _query.isEmpty
              ? 'Các phiên đã được giảng viên duyệt sẽ hiện ở đây.'
              : 'Thử từ khoá khác hoặc bỏ lọc môn học.',
          compact: true,
        ),
        itemBuilder: (context, s) => SessionTile(
          session: s,
          showStatus: false,
          onTap: () => Navigator.of(
            context,
          ).pushNamed(AppRoutes.qbankPractice, arguments: s.sessionId),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  static final _pill = OutlineInputBorder(
    borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
    borderSide: BorderSide.none,
  );

  final TextEditingController search;
  final String query;
  final bool isLecturer;
  final ValueChanged<String> onSearch;
  final ValueChanged<SubjectModel> onPickSubject;
  final VoidCallback onPropose;

  const _Header({
    required this.search,
    required this.query,
    required this.isLecturer,
    required this.onSearch,
    required this.onPickSubject,
    required this.onPropose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QbankBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Shortcut(
                      icon: AppIcons.add,
                      color: AppColors.primary600,
                      label: 'Đề xuất câu hỏi',
                      onTap: onPropose,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Shortcut(
                      icon: AppIcons.inbox,
                      color: AppColors.infoDark,
                      label: 'Phiên của tôi',
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.qbankMySubmissions),
                    ),
                  ),
                  // Sinh đề chỉ dành cho giảng viên (sinh viên gọi bị 403)
                  if (isLecturer) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Shortcut(
                        icon: AppIcons.exam,
                        color: AppColors.secondary700,
                        label: 'Đề thi',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.examMyExams),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: search,
                textInputAction: TextInputAction.search,
                onSubmitted: onSearch,
                decoration: InputDecoration(
                  hintText: 'Tìm phiên theo tên, môn học...',
                  prefixIcon: const Icon(AppIcons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xoá tìm kiếm',
                          icon: const Icon(AppIcons.close, size: 18),
                          onPressed: () {
                            search.clear();
                            onSearch('');
                          },
                        ),
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                  isDense: true,
                  // Theme chung đặt enabledBorder / focusedBorder (viền vuông
                  // của ô nhập) đè lên `border`, nên khai báo đủ ở đây để ô
                  // tìm kiếm luôn bo tròn kiểu pill.
                  border: _pill,
                  enabledBorder: _pill,
                  disabledBorder: _pill,
                  focusedBorder: _pill.copyWith(
                    borderSide: const BorderSide(
                      color: AppColors.primary600,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              BlocBuilder<
                LoadCubit<List<SubjectModel>>,
                LoadState<List<SubjectModel>>
              >(
                builder: (context, state) {
                  final subjects = state.data ?? const <SubjectModel>[];
                  if (subjects.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final s in subjects)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(s.code),
                                tooltip: s.name,
                                selected: query == s.code,
                                showCheckmark: false,
                                selectedColor: AppColors.primary50,
                                labelStyle: theme.textTheme.labelLarge
                                    ?.copyWith(
                                      color: query == s.code
                                          ? AppColors.primary700
                                          : AppColors.textPrimary,
                                    ),
                                onSelected: (_) => onPickSubject(s),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SectionGap(),
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: QbankSectionTitle(
            query.isEmpty ? 'Phiên câu hỏi đã duyệt' : 'Kết quả cho "$query"',
          ),
        ),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.backgroundSecondary,
    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
    child: InkWell(
      borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}
