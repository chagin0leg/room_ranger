import 'package:room_ranger/utils/date_utils.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final preposition = _getPrepositionForFrom(start.day);
  if (start.year == end.year) {
    if (start.year != currentYear) {
      // Всегда для других лет
      return 'в ${start.year} году $preposition ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}';
    } else {
      // Для текущего года только если есть интервалы в других годах
      return hasMultipleYears
          ? 'в этом году $preposition ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}'
          : '$preposition ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}';
    }
  } else {
    // Интервал пересекает годы
    return '$preposition ${_formatDate(start)} по ${_formatDate(end)}';
  }
}

/// Формирует текст сообщения для бронирования на основе выбранных дней для всех комнат.
String buildTelegramBookingMessage({
  required Map<int, Set<DateTime>> selectedDaysByRoom,
  required int selectedMonth,
}) {
  String getGreeting() => switch (DateTime.now().hour) {
        >= 5 && < 12 => 'Доброе утро!',
        >= 12 && < 17 => 'Добрый день!',
        >= 17 && < 23 => 'Добрый вечер!',
        _ => 'Доброй ночи!'
      };

  // Подсчитываем количество комнат с выбранными датами
  final roomsWithDates = selectedDaysByRoom.entries
      .where((entry) => entry.value.isNotEmpty)
      .length;

  String getBookingPhrase() {
    return (roomsWithDates == 0)
        ? 'У меня есть несколько вопросов по бронированию:\n1. '
        : 'Хотелось бы забронировать номер${roomsWithDates == 1 ? '' : 'а'} на следующие даты:\n';
  }

  String message = '${getGreeting()}\n${getBookingPhrase()}';

  // Проверяем, есть ли выбранные даты
  final hasAnyDates =
      selectedDaysByRoom.values.any((dates) => dates.isNotEmpty);
  if (!hasAnyDates) {
    return message;
  }

  // Формируем список комнат с датами
  final roomEntries = <String>[];

  for (final entry in selectedDaysByRoom.entries) {
    final roomNumber = entry.key;
    final selectedDays = entry.value;

    if (selectedDays.isEmpty) continue;

    final sortedDays = selectedDays.toList()..sort((a, b) => a.compareTo(b));
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
  message += '\n\n__Заявка отправлена через Room Ranger.__';

  return message;
}

/// Открывает Telegram с готовым сообщением для отправки.
Future<void> sendTelegramBookingMessage(String message) async {
  final url = 'https://t.me/MyZhiraf?text=${Uri.encodeComponent(message)}';
  await launchUrl(Uri.parse(url));
}

/// Формирует текст для отображения выбранных дат (без приветствия и и прочих слов).
String formatBookingDatesText({
  required Set<DateTime> selectedDays,
  required int selectedMonth,
}) {
  if (selectedDays.isEmpty) return '';

  final sortedDays = selectedDays.toList()..sort((a, b) => a.compareTo(b));
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
  required Map<int, Set<DateTime>> selectedDaysByRoom,
  required int selectedMonth,
}) {
  // Проверяем, есть ли выбранные даты
  final hasAnyDates =
      selectedDaysByRoom.values.any((dates) => dates.isNotEmpty);
  if (!hasAnyDates) return '';

  // Формируем список комнат с датами
  final roomEntries = <String>[];

  for (final entry in selectedDaysByRoom.entries) {
    final roomNumber = entry.key;
    final selectedDays = entry.value;

    if (selectedDays.isEmpty) continue;

    final sortedDays = selectedDays.toList()..sort((a, b) => a.compareTo(b));
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
