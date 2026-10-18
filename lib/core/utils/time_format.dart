import 'package:intl/intl.dart';

/// Định dạng thời gian kiểu mạng xã hội (tiếng Việt).
class TimeFormat {
  TimeFormat._();

  /// "Vừa xong", "5 phút trước", "2 giờ trước", "Hôm qua", "3 ngày trước",
  /// sau đó là ngày tháng.
  static String ago(DateTime? time, {DateTime? now}) {
    if (time == null) return '';
    final current = now ?? DateTime.now();
    final diff = current.difference(time);
    if (diff.isNegative || diff.inSeconds < 45) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    if (time.year == current.year) {
      return DateFormat('dd/MM').format(time);
    }
    return DateFormat('dd/MM/yyyy').format(time);
  }

  static String date(DateTime? time) =>
      time == null ? '' : DateFormat('dd/MM/yyyy').format(time);

  static String dateTime(DateTime? time) =>
      time == null ? '' : DateFormat('HH:mm dd/MM/yyyy').format(time);

  /// Rút gọn số: 1200 -> 1,2K; 1500000 -> 1,5M
  static String compact(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) {
      final v = n / 1000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1).replaceAll('.', ',')}K'
          .replaceAll(',0K', 'K');
    }
    final v = n / 1000000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1).replaceAll('.', ',')}M'
        .replaceAll(',0M', 'M');
  }

  /// 125 -> "2:05"
  static String duration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
