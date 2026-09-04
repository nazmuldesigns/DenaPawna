import 'package:intl/intl.dart';

/// Bangla-friendly date/time formatting helpers.
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _timeFmt = DateFormat('hh:mm a');
  static final DateFormat _monthFmt = DateFormat('MMMM yyyy');
  static final DateFormat _isoFmt = DateFormat('yyyy-MM-dd');

  static String formatDate(DateTime date) => _dateFmt.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFmt.format(date);
  static String formatTime(DateTime date) => _timeFmt.format(date);
  static String formatMonth(DateTime date) => _monthFmt.format(date);
  static String formatIso(DateTime date) => _isoFmt.format(date);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static DateTime endOfMonth(DateTime d) =>
      DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999);

  static String relativeLabel(DateTime date) {
    final now = DateTime.now();
    if (isSameDay(date, now)) return 'আজ';
    final yesterday = now.subtract(const Duration(days: 1));
    if (isSameDay(date, yesterday)) return 'গতকাল';
    return formatDate(date);
  }
}
