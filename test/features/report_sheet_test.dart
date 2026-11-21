import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/data/repositories/report_repository.dart';
import 'package:quizhub/shared/report/report_sheet.dart';

Future<void> _show(WidgetTester tester, ReportTarget target) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showReportSheet(context, target: target, targetId: 1),
            child: const Text('báo cáo'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('báo cáo'));
  await tester.pumpAndSettle();
}

void main() {
  const cases = {
    ReportTarget.post: ('Báo cáo bài viết', 'bài viết'),
    ReportTarget.comment: ('Báo cáo bình luận', 'bình luận'),
    ReportTarget.user: ('Báo cáo tài khoản', 'tài khoản'),
  };

  for (final entry in cases.entries) {
    testWidgets('tiêu đề báo cáo đúng với ${entry.key.name}', (tester) async {
      await _show(tester, entry.key);

      expect(find.text(entry.value.$1), findsOneWidget);
      expect(
        find.text('Hãy cho chúng tôi biết vấn đề của ${entry.value.$2} này.'),
        findsOneWidget,
      );
      expect(find.text('Báo cáo nội dung'), findsNothing);
    });
  }
}