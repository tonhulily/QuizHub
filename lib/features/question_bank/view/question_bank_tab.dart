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
import '../../../data/models/question_models.dart';
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

/// Nhóm kết quả khi đang tìm kiếm.
enum SearchGroup { sessions, questions }

class _QuestionBankTabState extends State<QuestionBankTab> {
  final _search = TextEditingController();
  String _query = '';
  SearchGroup _group = SearchGroup.sessions;

  late final PagedCubit<SubmissionSummary> _sessions = PagedCubit(
    (after) =>
        getIt<QuestionBankRepository>().searchSessions(_query, after: after),
  )..load();

  /// Chỉ tải khi có từ khoá (danh sách mặc định là các phiên đã duyệt).
  late final PagedCubit<QuestionHit> _questionHits = PagedCubit(
    (after) =>
        getIt<QuestionBankRepository>().searchQuestions(_query, after: after),
  );

  late final LoadCubit<List<SubjectModel>> _subjects = LoadCubit(
    () => getIt<SubjectRepository>().enrolled(),
  )..load();

  @override
  void dispose() {
    _search.dispose();
    _sessions.close();
    _questionHits.close();
    _subjects.close();
    super.dispose();
  }

  void _runSearch(String q) {
    final next = q.trim();
    if (next == _query) return;
    setState(() {
      _query = next;
      if (next.isEmpty) _group = SearchGroup.sessions;
    });
    _sessions
      ..reset()
      ..load();
    if (next.isNotEmpty) {
      _questionHits
        ..reset()
        ..load();
    }
  }

  /// Câu hỏi nằm trong phiên nào thì mở phiên đó, nhảy thẳng tới câu. Backend
  /// chưa trả phiên của câu (thiếu `session_id`) thì chỉ xem trước nội dung.
  void _openHit(QuestionHit h) {
    final sessionId = h.sessionId;
    if (sessionId != null) {
      Navigator.of(context).pushNamed(
        AppRoutes.qbankPractice,
        arguments: (sessionId: sessionId, questionId: h.questionId),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuestionPreviewSheet(hit: h),
    );
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
    final header = _Header(
      search: _search,
      query: _query,
      group: _group,
      isLecturer: role == UserRole.lecturer,
      onSearch: _runSearch,
      onPickSubject: _pickSubject,
      onPropose: _propose,
      onGroup: (g) => setState(() => _group = g),
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _sessions),
        BlocProvider.value(value: _questionHits),
        BlocProvider.value(value: _subjects),
      ],
      child: _query.isNotEmpty && _group == SearchGroup.questions
          ? PagedListView<QuestionHit>(
              key: const ValueKey(SearchGroup.questions),
              padding: EdgeInsets.zero,
              itemSpacing: ComponentTokens.postGap,
              header: header,
              emptyView: const EmptyView(
                icon: AppIcons.quizActive,
                title: 'Không tìm thấy câu hỏi phù hợp',
                message: 'Thử từ khoá khác hoặc bỏ lọc môn học.',
                compact: true,
              ),
              itemBuilder: (context, h) =>
                  _QuestionHitTile(hit: h, onTap: () => _openHit(h)),
            )
          : PagedListView<SubmissionSummary>(
              key: const ValueKey(SearchGroup.sessions),
              padding: EdgeInsets.zero,
              itemSpacing: ComponentTokens.postGap,
              header: header,
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
  final SearchGroup group;
  final bool isLecturer;
  final ValueChanged<String> onSearch;
  final ValueChanged<SubjectModel> onPickSubject;
  final VoidCallback onPropose;
  final ValueChanged<SearchGroup> onGroup;

  const _Header({
    required this.search,
    required this.query,
    required this.group,
    required this.isLecturer,
    required this.onSearch,
    required this.onPickSubject,
    required this.onPropose,
    required this.onGroup,
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
                  hintText: 'Tìm phiên, câu hỏi theo nội dung, môn học...',
                  prefixIcon: const Icon(AppIcons.search),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: search,
                    builder: (context, value, _) =>
                        value.text.isEmpty && query.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: 'Xoá tìm kiếm',
                            icon: const Icon(AppIcons.close, size: 18),
                            onPressed: () {
                              search.clear();
                              onSearch('');
                            },
                          ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QbankSectionTitle(
                query.isEmpty
                    ? 'Phiên câu hỏi đã duyệt'
                    : 'Kết quả cho "$query"',
              ),
              if (query.isNotEmpty) ...[
                const SizedBox(height: 8),
                SegmentedButton<SearchGroup>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: SearchGroup.sessions,
                      icon: Icon(AppIcons.inbox, size: 18),
                      label: Text('Phiên'),
                    ),
                    ButtonSegment(
                      value: SearchGroup.questions,
                      icon: Icon(AppIcons.quiz, size: 18),
                      label: Text('Câu hỏi'),
                    ),
                  ],
                  selected: {group},
                  onSelectionChanged: (v) => onGroup(v.first),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Một câu hỏi trong kết quả tìm kiếm.
class _QuestionHitTile extends StatelessWidget {
  final QuestionHit hit;
  final VoidCallback onTap;

  const _QuestionHitTile({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = hit;
    final meta = [
      '${h.options.length} phương án',
      if (h.ratingCount > 0) '${h.ratingCount} đánh giá',
      if (h.sessionId == null) 'Chỉ xem trước',
    ].join(' · ');
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (h.subjectName != null)
                    QbankChip(
                      label: h.subjectName!,
                      icon: AppIcons.subject,
                      color: AppColors.primary700,
                      background: AppColors.primary50,
                    ),
                  if (h.difficulty != Difficulty.unclassified)
                    QbankChip(label: h.difficulty.label),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                h.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const Icon(
                    AppIcons.chevronRight,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Xem trước câu hỏi khi chưa biết câu thuộc phiên nào.
class _QuestionPreviewSheet extends StatelessWidget {
  final QuestionHit hit;
  const _QuestionPreviewSheet({required this.hit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hit.questionCode ?? 'Câu hỏi',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(hit.content, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            for (final o in hit.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${o.key}. ${o.text}'),
              ),
            const SizedBox(height: 8),
            const ExplanationBox(
              title: 'Chưa mở được phiên chứa câu này',
              text:
                  'Máy chủ chưa cho biết câu hỏi thuộc phiên nào. Hãy tìm '
                  'theo tên phiên ở nhóm "Phiên" để luyện tập.',
              icon: AppIcons.info,
              color: AppColors.infoDark,
              background: AppColors.infoLight,
            ),
          ],
        ),
      ),
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
