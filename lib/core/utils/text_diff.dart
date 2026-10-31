/// So sánh hai đoạn văn theo từ, để tô phần khác nhau (vd bản gốc và bản AI
/// sửa của một câu hỏi).
enum DiffOp {
  /// Có ở cả hai bản
  same,

  /// Chỉ có ở bản mới
  added,

  /// Chỉ có ở bản cũ
  removed,
}

class DiffPart {
  final DiffOp op;
  final String text;
  const DiffPart(this.op, this.text);

  @override
  bool operator ==(Object other) =>
      other is DiffPart && other.op == op && other.text == text;

  @override
  int get hashCode => Object.hash(op, text);

  @override
  String toString() => '${op.name}("$text")';
}

/// Chia thành từ và khoảng trắng (giữ nguyên khoảng trắng để ghép lại đúng).
final _tokens = RegExp(r'\s+|[^\s]+');

/// Bảng LCS cần (n+1)*(m+1) ô; câu hỏi tối đa 500 từ nên bình thường rất nhỏ.
/// Quá giới hạn này thì coi như thay cả đoạn, tránh treo máy.
const _maxCells = 1000000;

/// Các đoạn giống / thêm / bớt từ [before] sang [after], các đoạn liền nhau
/// cùng loại đã gộp lại. Ghép các đoạn `same` + `removed` ra [before], `same`
/// + `added` ra [after].
List<DiffPart> diffWords(String before, String after) {
  if (before == after) {
    return before.isEmpty ? const [] : [DiffPart(DiffOp.same, before)];
  }
  final a = [for (final m in _tokens.allMatches(before)) m.group(0)!];
  final b = [for (final m in _tokens.allMatches(after)) m.group(0)!];
  if ((a.length + 1) * (b.length + 1) > _maxCells) {
    return [
      if (before.isNotEmpty) DiffPart(DiffOp.removed, before),
      if (after.isNotEmpty) DiffPart(DiffOp.added, after),
    ];
  }

  // lcs[i][j] = độ dài dãy con chung dài nhất của a[i..] và b[j..]
  final lcs = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }

  final parts = <DiffPart>[];
  void push(DiffOp op, String t) {
    if (parts.isNotEmpty && parts.last.op == op) {
      parts[parts.length - 1] = DiffPart(op, parts.last.text + t);
    } else {
      parts.add(DiffPart(op, t));
    }
  }

  var i = 0, j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      push(DiffOp.same, a[i]);
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      push(DiffOp.removed, a[i++]);
    } else {
      push(DiffOp.added, b[j++]);
    }
  }
  while (i < a.length) {
    push(DiffOp.removed, a[i++]);
  }
  while (j < b.length) {
    push(DiffOp.added, b[j++]);
  }
  return _joinChanges(parts);
}

/// Khoảng trắng chung kẹp giữa hai chỗ sửa ("Linear probing" -> "Open
/// addressing") tính luôn vào chỗ sửa, rồi gom mỗi cụm sửa thành một đoạn
/// bỏ + một đoạn thêm, để tô liền một khối thay vì từng từ lẻ.
List<DiffPart> _joinChanges(List<DiffPart> parts) {
  bool changed(int k) => parts[k].op != DiffOp.same;
  final out = <DiffPart>[];
  var removed = '', added = '';
  void flush() {
    if (removed.isNotEmpty) out.add(DiffPart(DiffOp.removed, removed));
    if (added.isNotEmpty) out.add(DiffPart(DiffOp.added, added));
    removed = added = '';
  }

  for (var k = 0; k < parts.length; k++) {
    final p = parts[k];
    final gap =
        p.op == DiffOp.same &&
        p.text.trim().isEmpty &&
        k > 0 &&
        k < parts.length - 1 &&
        changed(k - 1) &&
        changed(k + 1);
    if (gap) {
      removed += p.text;
      added += p.text;
    } else if (p.op == DiffOp.removed) {
      removed += p.text;
    } else if (p.op == DiffOp.added) {
      added += p.text;
    } else {
      flush();
      out.add(p);
    }
  }
  flush();
  return out;
}
