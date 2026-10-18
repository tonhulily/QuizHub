import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import 'link_text.dart';

/// Văn bản dài: thu gọn tối đa [maxLines] dòng kèm nút "Xem thêm".
///
/// Theo yêu cầu: bấm "Xem thêm" sẽ mở rộng và KHÔNG thu gọn lại được.
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;

  const ExpandableText(this.text, {super.key, this.style, this.maxLines = 5});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant ExpandableText old) {
    super.didUpdateWidget(old);
    // Nội dung đổi (vd sau khi sửa bài) thì tính lại, nhưng giữ trạng thái mở
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? Theme.of(context).textTheme.bodyMedium!;

    return LayoutBuilder(
      builder: (context, constraints) {
        var overflows = false;
        if (!_expanded) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: widget.maxLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          overflows = painter.didExceedMaxLines;
          painter.dispose();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinkText(
              widget.text,
              style: style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: TextOverflow.ellipsis,
            ),
            if (overflows)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = true),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Xem thêm',
                    style: style.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
