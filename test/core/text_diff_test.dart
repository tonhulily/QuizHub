import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/utils/text_diff.dart';

/// Ghép lại bản cũ / bản mới từ kết quả diff.
String _side(List<DiffPart> parts, DiffOp skip) => [
  for (final p in parts)
    if (p.op != skip) p.text,
].join();

void main() {
  test('giống nhau thì một đoạn same', () {
    expect(diffWords('O(log n)', 'O(log n)'), const [
      DiffPart(DiffOp.same, 'O(log n)'),
    ]);
    expect(diffWords('', ''), isEmpty);
  });

  test('chỉ tô đúng từ bị thay, giữ phần chung', () {
    final parts = diffWords('Độ phức tạp tìm kiếm', 'Độ phức tạp chèn');
    expect(parts, const [
      DiffPart(DiffOp.same, 'Độ phức tạp '),
      DiffPart(DiffOp.removed, 'tìm kiếm'),
      DiffPart(DiffOp.added, 'chèn'),
    ]);
  });

  test('thêm ở cuối / bản cũ rỗng', () {
    expect(diffWords('Cây AVL', 'Cây AVL cân bằng'), const [
      DiffPart(DiffOp.same, 'Cây AVL'),
      DiffPart(DiffOp.added, ' cân bằng'),
    ]);
    expect(diffWords('', 'Mới'), const [DiffPart(DiffOp.added, 'Mới')]);
    expect(diffWords('Cũ', ''), const [DiffPart(DiffOp.removed, 'Cũ')]);
  });

  test('cụm từ bị thay cả cụm thì tô liền một khối', () {
    expect(diffWords('Linear probing', 'Open addressing'), const [
      DiffPart(DiffOp.removed, 'Linear probing'),
      DiffPart(DiffOp.added, 'Open addressing'),
    ]);
  });

  test('ghép lại đúng hai bản gốc', () {
    const a = 'Kỹ thuật nào xử lý đụng độ  bằng danh sách?';
    const b = 'Kỹ thuật nào giải quyết đụng độ bằng danh sách liên kết?';
    final parts = diffWords(a, b);
    expect(_side(parts, DiffOp.added), a);
    expect(_side(parts, DiffOp.removed), b);
  });
}
