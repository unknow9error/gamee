/// A calendar day follows the device's local date, independent of elapsed hours.
String calendarDayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

DateTime parseCalendarDayKey(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid calendar day');
  }
  final parts = value.split('-').map(int.parse).toList();
  final day = DateTime(parts[0], parts[1], parts[2]);
  if (calendarDayKey(day) != value) {
    throw const FormatException('Invalid calendar day');
  }
  return day;
}

DateTime calendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);
DateTime previousCalendarDay(DateTime day) =>
    DateTime(day.year, day.month, day.day - 1);
