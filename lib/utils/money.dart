import 'package:intl/intl.dart';

/// Helpers for safe financial number handling.
/// All monetary values are stored internally as integer paisa
/// (1 taka = 100 paisa) to avoid floating point rounding errors.
class Money {
  Money._();

  static final NumberFormat _bnGroup = NumberFormat.decimalPattern('en_US');

  /// Convert a taka double amount (as entered by user) into integer paisa.
  /// Rounds to the nearest paisa to avoid float drift.
  static int takaToPaisa(double taka) => (taka * 100).round();

  /// Convert integer paisa into taka double for display/math.
  static double paisaToTaka(int paisa) => paisa / 100.0;

  /// Format paisa as a BDT currency string, e.g. "৳ 1,250.00"
  static String formatPaisa(int paisa, {bool showDecimal = true}) {
    final taka = paisaToTaka(paisa);
    return formatTaka(taka, showDecimal: showDecimal);
  }

  /// Format a taka amount as BDT currency string, e.g. "৳ 1,250"
  static String formatTaka(double taka, {bool showDecimal = false}) {
    final isNegative = taka < 0;
    final absTaka = taka.abs();
    String formatted;
    if (showDecimal) {
      formatted = absTaka.toStringAsFixed(2);
      final parts = formatted.split('.');
      formatted = '${_bnGroup.format(int.parse(parts[0]))}.${parts[1]}';
    } else {
      formatted = _bnGroup.format(absTaka.round());
    }
    return '${isNegative ? '-' : ''}৳$formatted';
  }

  /// Parse a user-entered amount string (supports both Bangla and Latin
  /// digits, and comma separators) into a double taka value.
  /// Returns null if invalid or <= 0.
  static double? parseAmountInput(String input) {
    if (input.trim().isEmpty) return null;
    final normalized = _convertBanglaDigitsToLatin(input)
        .replaceAll(',', '')
        .replaceAll('৳', '')
        .trim();
    final value = double.tryParse(normalized);
    if (value == null || value <= 0) return null;
    // Guard against unreasonable / overflow values.
    if (value > 999999999) return null;
    return value;
  }

  static String _convertBanglaDigitsToLatin(String input) {
    const bnDigits = '০১২৩৪৫৬৭৮৯';
    final buffer = StringBuffer();
    for (final ch in input.runes) {
      final char = String.fromCharCode(ch);
      final idx = bnDigits.indexOf(char);
      if (idx != -1) {
        buffer.write(idx.toString());
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}
