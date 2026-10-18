import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design_system/app_colors.dart';

/// Text tự nhận diện link http/https và cho phép bấm mở trình duyệt.
class LinkText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  const LinkText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  static final RegExp urlPattern = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<InlineSpan> _build(TextStyle base) {
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in LinkText.urlPattern.allMatches(widget.text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, m.start)));
      }
      var url = m.group(0)!;
      // Bỏ dấu câu dính cuối link
      var trailing = '';
      while (url.isNotEmpty && '.,;:!?)'.contains(url[url.length - 1])) {
        trailing = url[url.length - 1] + trailing;
        url = url.substring(0, url.length - 1);
      }
      final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          recognizer: recognizer,
          style: base.copyWith(
            color: AppColors.textLink,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textLink,
          ),
        ),
      );
      if (trailing.isNotEmpty) spans.add(TextSpan(text: trailing));
      cursor = m.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(style: base, children: _build(base)),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
