import 'package:intl/intl.dart';

NumberFormat _currency = NumberFormat.simpleCurrency(name: 'USD');
final DateFormat _shortDate = DateFormat('MMM d, yyyy');
final DateFormat _dayLabel = DateFormat('EEE');
final DateFormat _dayNumber = DateFormat('d');
final DateFormat _monthDay = DateFormat('MMM d');
final DateFormat _monthLabel = DateFormat('MMM');

String formatCurrency(double amount) => _currency.format(amount);

String formatSignedCurrency(double amount, {required bool isIncome}) {
  final sign = isIncome ? '+' : '−';
  return '$sign${_currency.format(amount.abs())}';
}

String formatDate(DateTime date) {
  final now = DateTime.now();
  final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
  final yesterday = now.subtract(const Duration(days: 1));
  final isYesterday =
      date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  if (isToday) return 'Today, ${DateFormat('h:mm a').format(date)}';
  if (isYesterday) return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
  return _shortDate.format(date);
}

String formatDayHeader(DateTime date) {
  final now = DateTime.now();
  final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
  final yesterday = now.subtract(const Duration(days: 1));
  final isYesterday =
      date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  if (isToday) return 'Today';
  if (isYesterday) return 'Yesterday';
  return _shortDate.format(date);
}

String formatDayLabel(DateTime date) => _dayLabel.format(date);
String formatDayNumber(DateTime date) => _dayNumber.format(date);
String formatMonthDay(DateTime date) => _monthDay.format(date);
String formatMonthLabel(DateTime date) => _monthLabel.format(date);

void setAppCurrency(String currencyCode) {
  _currency = NumberFormat.simpleCurrency(name: currencyCode);
}

String currencySymbolFor(String currencyCode) => NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
