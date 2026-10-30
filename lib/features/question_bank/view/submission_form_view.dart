import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/question_models.dart';
import '../../../data/models/session_models.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/media_repository.dart';
import '../../../data/repositories/subject_repository.dart';
import '../../../data/repositories/submission_repository.dart';
import '../../../di/locator.dart';
import '../../../shared/media/image_picking.dart';
import '../cubit/load_cubit.dart';
import '../cubit/submission_form_cubit.dart';
import '../widgets/qbank_widgets.dart';

/// Tạo phiên đề xuất mới ([initial] null) hoặc sửa phiên còn chờ duyệt.
/// Lưu xong `pop(true)`.
class SubmissionFormView extends StatelessWidget {
  final SubmissionDetail? initial;
  const SubmissionFormView({super.key, this.initial});

  @override
  Widget build(BuildContext context) {
    final d = initial;
    return BlocProvider(
      create: (_) => SubmissionFormCubit(
        getIt<SubmissionRepository>(),
        getIt<SubjectRepository>(),
        sessionId: d?.sessionId,
        currentSubject: d?.subjectId == null
            ? null
            : SubjectModel(
                subjectId: d!.subjectId!,
                code: d.subjectCode ?? '',
                name: d.subjectName ?? 'Môn học',
              ),
      )..loadSubjects(),
      child: _Form(initial: d),
    );
  }
}

/// Bộ điều khiển nhập liệu của một câu hỏi.
class _QuestionEditor {
  final int? questionId;

  /// URL ảnh minh hoạ đã upload (upload ngay khi chọn ảnh).
  final List<String> mediaUrls;
  final TextEditingController content;
  final TextEditingController explanation;
  final List<TextEditingController> options;

  /// URL ảnh của từng phương án (null = phương án chỉ có chữ).
  final List<String?> optionMedia;

  /// Đáp án đúng. Câu mới để trống, bắt người dùng tự chọn (chọn sẵn A thì
  /// dễ gửi luôn mà quên kiểm tra).
  int? correct;
  QuestionSource source;
  double confidence;

  /// Vị trí các ô để cuộn tới khi báo lỗi.
  final contentKey = GlobalKey();
  final imagesKey = GlobalKey();
  final optionsKey = GlobalKey();
  final confidenceKey = GlobalKey();

  _QuestionEditor({
    this.questionId,
    List<String> mediaUrls = const [],
    String content = '',
    String explanation = '',
    List<String> options = const ['', '', '', ''],
    List<String?>? optionMedia,
    this.correct,
    this.source = QuestionSource.human,
    this.confidence = 3,
  }) : mediaUrls = [...mediaUrls],
       content = TextEditingController(text: content),
       explanation = TextEditingController(text: explanation),
       options = [for (final o in options) TextEditingController(text: o)],
       optionMedia =
           optionMedia ?? List.filled(options.length, null, growable: true);

  factory _QuestionEditor.from(SubmissionQuestion q) {
    final correct = q.options.indexWhere((o) => o.isCorrect == true);
    return _QuestionEditor(
      questionId: q.questionId,
      mediaUrls: q.imageUrls,
      content: q.content,
      explanation: q.explanation ?? '',
      options: [for (final o in q.options) o.text],
      optionMedia: [for (final o in q.options) o.mediaUrl],
      correct: correct < 0 ? null : correct,
      source: q.source,
      confidence: q.confidence ?? 3,
    );
  }

  static String keyOf(int i) => String.fromCharCode(65 + i); // A, B, C...

  void addOption() {
    options.add(TextEditingController());
    optionMedia.add(null);
  }

  void removeOption(int i) {
    options.removeAt(i).dispose();
    optionMedia.removeAt(i);
    final c = correct;
    if (c == i) {
      correct = null;
    } else if (c != null && c > i) {
      correct = c - 1;
    }
  }

  GlobalKey anchorOf(DraftField f) => switch (f) {
    DraftField.images => imagesKey,
    DraftField.options || DraftField.correct => optionsKey,
    DraftField.confidence => confidenceKey,
    _ => contentKey,
  };

  QuestionDraft toDraft() => QuestionDraft(
    questionId: questionId,
    content: content.text,
    mediaUrls: mediaUrls,
    explanation: explanation.text,
    source: source,
    confidence: confidence,
    options: [
      for (var i = 0; i < options.length; i++)
        QuestionOption(
          key: keyOf(i),
          text: options[i].text,
          isCorrect: i == correct,
          mediaUrl: optionMedia[i],
        ),
    ],
  );

  void dispose() {
    content.dispose();
    explanation.dispose();
    for (final c in options) {
      c.dispose();
    }
  }
}

class _Form extends StatefulWidget {
  final SubmissionDetail? initial;
  const _Form({required this.initial});

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _content = TextEditingController(text: widget.initial?.content);
  late final _source = TextEditingController(text: widget.initial?.sourceUrl);
  late int? _subjectId = widget.initial?.subjectId;
  late final List<_QuestionEditor> _questions = [
    for (final q in widget.initial?.questions ?? const <SubmissionQuestion>[])
      _QuestionEditor.from(q),
    if (widget.initial == null) _QuestionEditor(),
  ];

  /// Lỗi nhập liệu đang hiển thị (viền đỏ + dòng báo ngay tại ô đó).
  DraftIssue? _issue;
  final _subjectKey = GlobalKey();
  final _titleKey = GlobalKey();
  final _sourceKey = GlobalKey();
  final _questionsKey = GlobalKey();

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _source.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  SessionDraft _draft() => SessionDraft(
    subjectId: _subjectId ?? 0,
    title: _title.text,
    content: _content.text,
    sourceUrl: _source.text,
    questions: [for (final q in _questions) q.toDraft()],
  );

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final draft = _draft();
    final issue = checkSessionDraft(draft);
    if (issue != null) {
      _showIssue(issue);
      return;
    }
    setState(() => _issue = null);
    final error = await context.read<SubmissionFormCubit>().submit(draft);
    if (!mounted) return;
    if (error != null) {
      AppFeedback.error(context, error);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  /// Đánh dấu ô lỗi rồi cuộn tới đó (sau khi khung hình mới đã dựng xong).
  void _showIssue(DraftIssue issue) {
    setState(() => _issue = issue);
    final key = switch (issue.field) {
      DraftField.subject => _subjectKey,
      DraftField.title => _titleKey,
      DraftField.source => _sourceKey,
      DraftField.questions => _questionsKey,
      final f => _questions[issue.question!].anchorOf(f),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// Đang báo lỗi mà người dùng sửa thì kiểm tra lại: hết lỗi ở ô đó thì bỏ
  /// viền đỏ (lỗi ở ô khác sẽ báo ở lần bấm Gửi sau).
  void _edited() {
    final old = _issue;
    if (old == null) return;
    final now = checkSessionDraft(_draft());
    final next = old.sameSpot(now) ? now : null;
    if (next != old) setState(() => _issue = next);
  }

  /// Lỗi của ô thông tin phiên [f] (không thuộc câu hỏi nào).
  String? _errorOf(DraftField f) {
    final i = _issue;
    return i != null && i.field == f && i.question == null ? i.message : null;
  }

  Future<void> _removeQuestion(int i) async {
    final q = _questions[i];
    final hasText = q.content.text.trim().isNotEmpty;
    if (hasText) {
      final ok = await showConfirmDialog(
        context,
        title: 'Xoá câu ${i + 1}?',
        message: 'Nội dung câu hỏi này sẽ bị bỏ.',
        confirmLabel: 'Xoá',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _questions.removeAt(i).dispose());
    _edited();
  }

  void _addQuestion() {
    if (_questions.length >= SubmissionLimits.maxQuestions) {
      AppFeedback.info(
        context,
        'Mỗi phiên tối đa ${SubmissionLimits.maxQuestions} câu hỏi.',
      );
      return;
    }
    setState(() => _questions.add(_QuestionEditor()));
  }

  /// Hỏi lại trước khi bỏ form đang nhập dở.
  Future<void> _confirmLeave() async {
    final dirty =
        _title.text.trim().isNotEmpty ||
        _questions.any((q) => q.content.text.trim().isNotEmpty);
    if (dirty) {
      final ok = await showConfirmDialog(
        context,
        title: 'Bỏ thay đổi?',
        message: 'Những gì bạn vừa nhập sẽ không được lưu.',
        confirmLabel: 'Bỏ',
        destructive: true,
      );
      if (!ok) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final saving = context.select<SubmissionFormCubit, bool>(
      (c) => c.state.saving,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !saving) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        appBar: AppBar(
          title: Text(isEdit ? 'Sửa phiên đề xuất' : 'Đề xuất câu hỏi'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: saving ? null : _submit,
                child: Text(isEdit ? 'Lưu' : 'Gửi'),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              QbankBlock(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SubjectPicker(
                      key: _subjectKey,
                      value: _subjectId,
                      errorText: _errorOf(DraftField.subject),
                      onChanged: (id) {
                        setState(() => _subjectId = id);
                        _edited();
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      key: _titleKey,
                      controller: _title,
                      label: 'Tiêu đề phiên *',
                      hint: 'VD: Ôn tập chương 3 - Cây nhị phân',
                      maxLength: SubmissionLimits.maxTitleLength,
                      errorText: _errorOf(DraftField.title),
                      onChanged: (_) => _edited(),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _content,
                      label: 'Mô tả (tuỳ chọn)',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      key: _sourceKey,
                      controller: _source,
                      label: 'Link nguồn tham khảo (tuỳ chọn)',
                      keyboardType: TextInputType.url,
                      errorText: _errorOf(DraftField.source),
                      onChanged: (_) => _edited(),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < _questions.length; i++) ...[
                const SectionGap(),
                _QuestionCard(
                  key: ObjectKey(_questions[i]),
                  index: i,
                  editor: _questions[i],
                  issue: _issue?.question == i ? _issue : null,
                  canRemove: _questions.length > 1,
                  onRemove: () => _removeQuestion(i),
                  onChanged: () {
                    setState(() {});
                    _edited();
                  },
                  onEdited: _edited,
                ),
              ],
              const SectionGap(),
              QbankBlock(
                key: _questionsKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorOf(DraftField.questions) case final m?) ...[
                      _ErrorLine(m),
                      const SizedBox(height: 8),
                    ],
                    AppButton(
                      label: 'Thêm câu hỏi',
                      icon: AppIcons.add,
                      variant: AppButtonVariant.outline,
                      onPressed: _addQuestion,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: isEdit ? 'Lưu thay đổi' : 'Gửi đề xuất',
                      loading: saving,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phiên sẽ ở trạng thái "Chờ duyệt". Bạn chỉ sửa hoặc xoá '
                      'được khi giảng viên chưa mở duyệt.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chọn môn: chỉ các môn đang học (đề xuất môn khác bị 403).
class _SubjectPicker extends StatelessWidget {
  final int? value;
  final String? errorText;
  final ValueChanged<int?> onChanged;

  const _SubjectPicker({
    super.key,
    required this.value,
    this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SubmissionFormCubit>().state;
    if (state.subjectsStatus == LoadStatus.loading) {
      return const SizedBox(height: 56, child: LoadingView());
    }
    if (state.subjectsStatus == LoadStatus.failure) {
      return ErrorView(
        error: state.error,
        compact: true,
        onRetry: context.read<SubmissionFormCubit>().loadSubjects,
      );
    }
    if (state.subjects.isEmpty) {
      return const ExplanationBox(
        title: 'Bạn chưa tham gia lớp học phần nào',
        text: 'Chỉ đề xuất được câu hỏi cho môn bạn đang học.',
        icon: AppIcons.errorOutline,
        color: AppColors.warningDark,
        background: AppColors.warningLight,
      );
    }
    final valid = state.subjects.any((s) => s.subjectId == value);
    return DropdownButtonFormField<int>(
      initialValue: valid ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Môn học *',
        prefixIcon: const Icon(AppIcons.subject),
        errorText: errorText,
      ),
      items: [
        for (final s in state.subjects)
          DropdownMenuItem(
            value: s.subjectId,
            child: Text(s.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final _QuestionEditor editor;

  /// Lỗi nhập liệu của câu này (null nếu không có).
  final DraftIssue? issue;
  final bool canRemove;
  final VoidCallback onRemove;

  /// Đổi cấu trúc câu (đáp án, ảnh, thêm / bớt phương án): dựng lại form.
  final VoidCallback onChanged;

  /// Gõ chữ trong các ô của câu (không cần dựng lại form).
  final VoidCallback onEdited;

  const _QuestionCard({
    super.key,
    required this.index,
    required this.editor,
    this.issue,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    required this.onEdited,
  });

  String? _errorOf(DraftField f, {int? option}) {
    final i = issue;
    return i != null && i.field == f && i.option == option ? i.message : null;
  }

  Future<void> _addQuestionImage(BuildContext context) async {
    final r = await pickAndUploadImage(context, purpose: MediaPurpose.question);
    if (r == null) return;
    editor.mediaUrls.add(r.url);
    onChanged();
  }

  Future<void> _setOptionImage(BuildContext context, int i) async {
    final r = await pickAndUploadImage(context, purpose: MediaPurpose.question);
    // Phương án có thể đã bị xoá trong lúc đang upload
    if (r == null || i >= editor.optionMedia.length) return;
    editor.optionMedia[i] = r.url;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = editor;
    final level = RatingLevel.fromValue(e.confidence)!;
    // Lỗi của cả nhóm phương án (thiếu / thừa phương án, chưa chọn đáp án đúng)
    final optionsError =
        _errorOf(DraftField.options) ?? _errorOf(DraftField.correct);
    final needCorrect = _errorOf(DraftField.correct) != null;
    return QbankBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Câu ${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.primary600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canRemove)
                IconButton(
                  tooltip: 'Xoá câu ${index + 1}',
                  icon: const Icon(AppIcons.delete, color: AppColors.error),
                  onPressed: onRemove,
                ),
            ],
          ),
          AppTextField(
            key: e.contentKey,
            controller: e.content,
            label: 'Nội dung câu hỏi *',
            maxLines: 4,
            errorText: _errorOf(DraftField.content),
            onChanged: (_) => onEdited(),
          ),
          const SizedBox(height: 8),
          _ImageStrip(
            key: e.imagesKey,
            urls: e.mediaUrls,
            onAdd: e.mediaUrls.length < SubmissionLimits.maxImagesPerQuestion
                ? () => _addQuestionImage(context)
                : null,
            onRemove: (i) {
              e.mediaUrls.removeAt(i);
              onChanged();
            },
          ),
          if (_errorOf(DraftField.images) case final m?) ...[
            const SizedBox(height: 6),
            _ErrorLine(m),
          ],
          const SizedBox(height: 16),
          Container(
            key: e.optionsKey,
            padding: optionsError == null
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(4, 8, 4, 0),
            decoration: optionsError == null
                ? null
                : BoxDecoration(
                    border: Border.all(color: AppColors.error),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _options(context, theme, optionsError, needCorrect),
            ),
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: e.explanation,
            label: 'Lời giải (tuỳ chọn)',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Nguồn câu hỏi',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<QuestionSource>(
            showSelectedIcon: false,
            segments: [
              for (final s in QuestionSource.values)
                ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {e.source},
            onSelectionChanged: (v) {
              e.source = v.first;
              onChanged();
            },
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                AppIcons.lock,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Giảng viên không thấy nguồn này (để duyệt và chấm khách '
                  'quan). Hãy chọn đúng: câu do AI sinh thì chọn "AI sinh".',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Độ tự tin: ${level.value} - ${level.label}',
            key: e.confidenceKey,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Slider(
            value: e.confidence,
            min: 0,
            max: 4,
            divisions: 4,
            label: level.label,
            activeColor: AppColors.primary600,
            onChanged: (v) {
              e.confidence = v;
              onChanged();
            },
          ),
          if (_errorOf(DraftField.confidence) case final m?) ...[
            _ErrorLine(m),
            const SizedBox(height: 6),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.backgroundTertiary,
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            ),
            child: Text(
              'Độ tự tin cho biết bạn chắc chắn câu hỏi đúng tới mức nào '
              '(0: có thể sai, 4: rất chắc chắn).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nhóm phương án: chọn đáp án đúng, nội dung, ảnh, thêm / bớt.
  List<Widget> _options(
    BuildContext context,
    ThemeData theme,
    String? groupError,
    bool needCorrect,
  ) {
    final e = editor;
    return [
      Text(
        'Phương án (chạm vòng tròn để chọn đáp án đúng)',
        style: theme.textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      if (groupError != null) ...[
        const SizedBox(height: 4),
        _ErrorLine(groupError),
      ],
      const SizedBox(height: 8),
      for (var i = 0; i < e.options.length; i++)
        Padding(
          key: ObjectKey(e.options[i]),
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Chọn ${_QuestionEditor.keyOf(i)} là đáp án đúng',
                    onPressed: () {
                      e.correct = i;
                      onChanged();
                    },
                    icon: Icon(
                      e.correct == i ? AppIcons.success : AppIcons.radioOff,
                      color: e.correct == i
                          ? AppColors.success
                          : needCorrect
                          ? AppColors.error
                          : AppColors.textTertiary,
                    ),
                  ),
                  Expanded(
                    child: AppTextField(
                      controller: e.options[i],
                      label: 'Phương án ${_QuestionEditor.keyOf(i)}',
                      errorText: _errorOf(DraftField.options, option: i),
                      onChanged: (_) => onEdited(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ảnh cho phương án ${_QuestionEditor.keyOf(i)}',
                    icon: Icon(
                      e.optionMedia[i] == null
                          ? AppIcons.photos
                          : AppIcons.photosFill,
                      color: e.optionMedia[i] == null
                          ? AppColors.textTertiary
                          : AppColors.primary600,
                    ),
                    onPressed: () => _setOptionImage(context, i),
                  ),
                  if (e.options.length > SubmissionLimits.minOptions)
                    IconButton(
                      tooltip: 'Bỏ phương án ${_QuestionEditor.keyOf(i)}',
                      icon: const Icon(AppIcons.close, size: 18),
                      onPressed: () {
                        e.removeOption(i);
                        onChanged();
                      },
                    ),
                ],
              ),
              if (e.optionMedia[i] case final url?)
                Padding(
                  padding: const EdgeInsets.only(left: 48, top: 6),
                  child: _Thumb(
                    url: url,
                    onRemove: () {
                      e.optionMedia[i] = null;
                      onChanged();
                    },
                  ),
                ),
            ],
          ),
        ),
      if (e.options.length < SubmissionLimits.maxOptions)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              e.addOption();
              onChanged();
            },
            icon: const Icon(AppIcons.add, size: 18),
            label: const Text('Thêm phương án'),
          ),
        ),
    ];
  }
}

/// Dòng báo lỗi đỏ ngay dưới ô nhập (cùng kiểu chữ lỗi của TextField).
class _ErrorLine extends StatelessWidget {
  final String message;
  const _ErrorLine(this.message);

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.error),
  );
}

/// Hàng ảnh minh hoạ của câu hỏi + ô "Thêm ảnh".
class _ImageStrip extends StatelessWidget {
  final List<String> urls;

  /// null khi đã đủ số ảnh tối đa.
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;

  const _ImageStrip({
    super.key,
    required this.urls,
    this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < urls.length; i++)
          _Thumb(url: urls[i], onRemove: () => onRemove(i)),
        if (onAdd != null)
          Material(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            child: InkWell(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
              onTap: onAdd,
              child: SizedBox(
                width: _Thumb.size,
                height: _Thumb.size,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(AppIcons.photos, color: AppColors.textSecondary),
                    const SizedBox(height: 4),
                    Text(
                      urls.isEmpty
                          ? 'Thêm ảnh'
                          : '${urls.length}/${SubmissionLimits.maxImagesPerQuestion}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ảnh vuông nhỏ (cắt giữa) có nút gỡ ở góc.
class _Thumb extends StatelessWidget {
  static const double size = 76;

  final String url;
  final VoidCallback onRemove;

  const _Thumb({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const ColoredBox(
              color: AppColors.chip,
              child: Icon(AppIcons.imageBroken, color: AppColors.textTertiary),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: CircleIconButton(
            icon: AppIcons.close,
            size: 24,
            iconSize: 14,
            background: AppColors.overlay,
            color: AppColors.white,
            tooltip: 'Gỡ ảnh',
            onTap: onRemove,
          ),
        ),
      ],
    ),
  );
}
