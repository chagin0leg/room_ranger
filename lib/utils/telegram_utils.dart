import 'package:room_ranger/utils/date_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:room_ranger/utils/calendar_day.dart';
import 'package:room_ranger/utils/price_utils.dart';

/// Вспомогательная функция для форматирования даты.
String _formatDate(DateTime date) {
  final currentYear = DateTime.now().year;
  final monthName = getMonthName(date.month, GrammaticalCase.genitive);
  if (date.year != currentYear) {
    return '${date.day} $monthName ${date.year}';
  }
  return '${date.day} $monthName';
}

/// Вспомогательная функция для группировки последовательных дней в интервалы.
List<List<DateTime>> _groupDaysToIntervals(List<DateTime> sortedDays) {
  if (sortedDays.isEmpty) return [];
  final intervals = <List<DateTime>>[];
  var currentInterval = <DateTime>[sortedDays.first];
  for (var i = 1; i < sortedDays.length; i++) {
    final prev = sortedDays[i - 1];
    final curr = sortedDays[i];
    if (curr.difference(prev).inDays == 1) {
      currentInterval.add(curr);
    } else {
      intervals.add(List.from(currentInterval));
      currentInterval = [curr];
    }
  }
  intervals.add(currentInterval);
  return intervals;
}

/// Вспомогательная функция для выбора правильного предлога перед числом ("с" или "со").
String _getPrepositionForFrom(int day) {
  // В русском языке перед "2" используется "со"
  return day == 2 ? 'со' : 'с';
}

/// Вспомогательная функция для форматирования интервала дат.
String _formatInterval(
    List<DateTime> interval, int currentYear, bool hasMultipleYears) {
  if (interval.length == 1) {
    return _formatDate(interval.first);
  }
  final start = interval.first;
  final end = interval.last;
  final nights = interval.length - 1; // Количество ночей
  final preposition = _getPrepositionForFrom(start.day);
  String baseText;
  
  if (start.year == end.year) {
    if (start.month == end.month) {
      // Один месяц
      if (start.year != currentYear) {
        baseText = 'в ${start.year} году $preposition ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}';
      } else {
        baseText = hasMultipleYears
            ? 'в этом году $preposition ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}'
            : '$preposition ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}';
      }
    } else {
      // Разные месяцы в одном году
      if (start.year != currentYear) {
        baseText = 'в ${start.year} году $preposition ${start.day} ${getMonthName(start.month, GrammaticalCase.genitive)} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}';
      } else {
        baseText = hasMultipleYears
            ? 'в этом году $preposition ${start.day} ${getMonthName(start.month, GrammaticalCase.genitive)} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}'
            : '$preposition ${start.day} ${getMonthName(start.month, GrammaticalCase.genitive)} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}';
      }
    }
  } else {
    // Интервал пересекает годы
    baseText = '$preposition ${_formatDate(start)} по ${_formatDate(end)}';
  }
  return '$baseText ($nights ${getNightWord(nights)})';
}

/// Формирует текст сообщения для бронирования на основе выбранных дней для всех комнат.
String buildTelegramBookingMessage({
  required Map<int, List<CalendarDay>> daysByRoom,
  required int selectedMonth,
}) {
  String getGreeting() => switch (DateTime.now().hour) {
        >= 5 && < 12 => 'Доброе утро!',
        >= 12 && < 17 => 'Добрый день!',
        >= 17 && < 23 => 'Добрый вечер!',
        _ => 'Доброй ночи!'
      };
  final roomsWithDates = daysByRoom.entries
      .where((entry) => entry.value.any((d) => d.status == DayStatus.selected))
      .length;
  String getBookingPhrase() {
    return (roomsWithDates == 0)
        ? 'У меня есть несколько вопросов по бронированию:\n1. '
        : 'Хотелось бы забронировать номер${roomsWithDates == 1 ? '' : 'а'} на следующие даты:\n';
  }
  String message = '${getGreeting()}\n${getBookingPhrase()}';
  final hasAnyDates =
      daysByRoom.values.any((days) => days.any((d) => d.status == DayStatus.selected));
  if (!hasAnyDates) {
    return message;
  }
  final roomEntries = <String>[];
  for (final entry in daysByRoom.entries) {
    final roomNumber = entry.key;
    final selectedDays = entry.value.where((d) => d.status == DayStatus.selected).toList();
    if (selectedDays.isEmpty) continue;
    final sortedDays = selectedDays.map((day) => day.date).toList()..sort((a, b) => a.compareTo(b));
    final intervals = _groupDaysToIntervals(sortedDays);
    final years = intervals.map((interval) => interval.first.year).toSet();
    final currentYear = DateTime.now().year;
    final hasMultipleYears = years.length > 1;
    final formattedIntervals = intervals.map((interval) {
      return _formatInterval(interval, currentYear, hasMultipleYears);
    }).toList();
    final roomText =
        'Номер $roomNumber:\n${formattedIntervals.map((interval) => '- $interval').join('\n')}';
    roomEntries.add(roomText);
  }
  message += '\n${roomEntries.join('\n')}';
  final allSelectedDays = <CalendarDay>[];
  for (final days in daysByRoom.values) {
    allSelectedDays.addAll(days.where((d) => d.status == DayStatus.selected));
  }
  if (allSelectedDays.isNotEmpty) {
    final priceInfo = getFullPriceInfo(allSelectedDays, daysByRoom: daysByRoom);
    message += '\n\n$priceInfo';
  }
  message += '\n\n__Заявка отправлена через Room Ranger.__';
  return message;
}

/// Открывает Telegram с готовым сообщением для отправки.
Future<void> sendTelegramBookingMessage(String message) async {
  final managerId = dotenv.env['TELEGRAM_MANAGER_ID'];
  final url = 'https://t.me/$managerId?text=${Uri.encodeComponent(message)}';
  await launchUrl(Uri.parse(url));
}

/// Формирует текст для отображения выбранных дат (без приветствия и и прочих слов).
String formatBookingDatesText({
  required List<CalendarDay> selectedDays,
  required int selectedMonth,
}) {
  if (selectedDays.isEmpty) return '';
  final sortedDays = selectedDays.map((day) => day.date).toList()..sort((a, b) => a.compareTo(b));
  final intervals = _groupDaysToIntervals(sortedDays);
  final years = intervals.map((interval) => interval.first.year).toSet();
  final currentYear = DateTime.now().year;
  final hasMultipleYears = years.length > 1;
  final formattedIntervals = intervals
      .map((interval) =>
          _formatInterval(interval, currentYear, hasMultipleYears))
      .toList();
  if (formattedIntervals.length == 1) {
    return formattedIntervals.first;
  }
  final lastInterval = formattedIntervals.removeLast();
  return '${formattedIntervals.join(", ")} и $lastInterval';
}

/// Формирует текст для отображения выбранных дат всех комнат (без приветствия).
String formatAllBookingDatesText({
  required Map<int, List<CalendarDay>> daysByRoom,
  required int selectedMonth,
}) {
  final hasAnyDates =
      daysByRoom.values.any((days) => days.any((d) => d.status == DayStatus.selected));
  if (!hasAnyDates) return '';
  final roomEntries = <String>[];
  for (final entry in daysByRoom.entries) {
    final roomNumber = entry.key;
    final selectedDays = entry.value.where((d) => d.status == DayStatus.selected).toList();
    if (selectedDays.isEmpty) continue;
    final sortedDays = selectedDays.map((day) => day.date).toList()..sort((a, b) => a.compareTo(b));
    final intervals = _groupDaysToIntervals(sortedDays);
    final years = intervals.map((interval) => interval.first.year).toSet();
    final currentYear = DateTime.now().year;
    final hasMultipleYears = years.length > 1;
    final formattedIntervals = intervals
        .map((interval) =>
            _formatInterval(interval, currentYear, hasMultipleYears))
        .toList();
    final roomText =
        'Номер $roomNumber:\n${formattedIntervals.map((interval) => '- $interval').join('\n')}';
    roomEntries.add(roomText);
  }
  return roomEntries.join('\n\n');
}
