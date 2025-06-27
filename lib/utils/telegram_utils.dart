import 'package:room_ranger/utils/date_utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// Формирует текст сообщения для бронирования на основе выбранных дней и месяца.
String buildTelegramBookingMessage({
  required Set<DateTime> selectedDays,
  required int selectedMonth,
}) {
  String formatDate(DateTime date) {
    final currentYear = DateTime.now().year;
    final monthName = getMonthName(date.month, GrammaticalCase.genitive);
    if (date.year != currentYear) {
      return '${date.day} $monthName ${date.year}';
    }
    return '${date.day} $monthName';
  }
  
  String getGreeting() => switch (DateTime.now().hour) {
        >= 5 && < 12 => 'Доброе утро!',
        >= 12 && < 17 => 'Добрый день!',
        >= 17 && < 23 => 'Добрый вечер!',
        _ => 'Доброй ночи!'
      };

  String result = '${getGreeting()}\nХочу забронировать номер';
  if (selectedDays.isEmpty) return result;

  final sortedDays = selectedDays.toList()..sort((a, b) => a.compareTo(b));

  // Группируем последовательные дни в интервалы
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

  // Определяем, есть ли интервалы в разных годах
  final years = intervals.map((interval) => interval.first.year).toSet();
  final currentYear = DateTime.now().year;
  final hasMultipleYears = years.length > 1;

  String formatInterval(List<DateTime> interval) {
    if (interval.length == 1) {
      return formatDate(interval.first);
    }
    final start = interval.first;
    final end = interval.last;
    if (start.year == end.year) {
      if (start.year != currentYear) {
        // Всегда для других лет
        return 'в ${start.year} году с ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}';
      } else {
        // Для текущего года только если есть интервалы в других годах
        return hasMultipleYears
          ? 'в этом году с ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}'
          : 'с ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}';
      }
    } else {
      // Интервал пересекает годы
      return 'с ${formatDate(start)} по ${formatDate(end)}';
    }
  }

  final formattedIntervals = intervals.map(formatInterval).toList();

  if (formattedIntervals.length == 1) {
    final interval = formattedIntervals.first;
    final hasInterval = interval.startsWith('с') || interval.startsWith('в этом году') || interval.startsWith('в ');
    return '$result ${hasInterval ? 'на даты ' : 'на '}$interval';
  }

  final lastInterval = formattedIntervals.removeLast();
  return '$result на даты: ${formattedIntervals.join(", ")} и $lastInterval';
}

/// Открывает Telegram с готовым сообщением для отправки.
Future<void> sendTelegramBookingMessage(String message) async {
  final url = 'https://t.me/MyZhiraf?text=${Uri.encodeComponent(message)}';
  await launchUrl(Uri.parse(url));
}

/// Формирует текст для отображения выбранных дат (без приветствия и фразы "Хочу забронировать номер").
String formatBookingDatesText({
  required Set<DateTime> selectedDays,
  required int selectedMonth,
}) {
  String formatDate(DateTime date) {
    final currentYear = DateTime.now().year;
    final monthName = getMonthName(date.month, GrammaticalCase.genitive);
    if (date.year != currentYear) {
      return '${date.day} $monthName ${date.year}';
    }
    return '${date.day} $monthName';
  }

  if (selectedDays.isEmpty) return '';

  final sortedDays = selectedDays.toList()..sort((a, b) => a.compareTo(b));

  // Группируем последовательные дни в интервалы
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

  // Определяем, есть ли интервалы в разных годах
  final years = intervals.map((interval) => interval.first.year).toSet();
  final currentYear = DateTime.now().year;
  final hasMultipleYears = years.length > 1;

  String formatInterval(List<DateTime> interval) {
    if (interval.length == 1) {
      return formatDate(interval.first);
    }
    final start = interval.first;
    final end = interval.last;
    if (start.year == end.year) {
      if (start.year != currentYear) {
        // Всегда для других лет
        return 'в ${start.year} году с ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}';
      } else {
        // Для текущего года только если есть интервалы в других годах
        return hasMultipleYears
          ? 'в этом году с ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}'
          : 'с ${start.day} по ${end.day} ${getMonthName(end.month, GrammaticalCase.genitive)}';
      }
    } else {
      // Интервал пересекает годы
      return 'с ${formatDate(start)} по ${formatDate(end)}';
    }
  }

  final formattedIntervals = intervals.map(formatInterval).toList();

  if (formattedIntervals.length == 1) {
    return formattedIntervals.first;
  }

  final lastInterval = formattedIntervals.removeLast();
  return '${formattedIntervals.join(", ")} и $lastInterval';
}
