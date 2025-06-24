import 'package:url_launcher/url_launcher.dart';

/// Формирует текст сообщения для бронирования на основе выбранных дней и месяца.
String buildTelegramBookingMessage({
  required Set<DateTime> selectedDays,
  required int selectedMonth,
  required String Function(DateTime) formatDate,
  required String Function() getGreeting,
}) {
  if (selectedDays.isEmpty) return '';

  final sortedDays = selectedDays.toList()
    ..sort((a, b) => a.compareTo(b));

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

  // Форматируем интервалы
  final formattedIntervals = intervals
      .map((interval) => interval.length == 1
          ? formatDate(interval.first)
          : 'с ${formatDate(interval.first)} по ${formatDate(interval.last)}')
      .toList();

  // Склеиваем интервалы с союзами
  if (formattedIntervals.length == 1) {
    final interval = formattedIntervals.first;
    final hasInterval = interval.startsWith('с');
    return '${getGreeting()}\nХочу забронировать номер ${hasInterval ? 'на даты ' : 'на '}$interval';
  }

  final lastInterval = formattedIntervals.removeLast();
  return '${getGreeting()}\nХочу забронировать номер на даты ${formattedIntervals.join(", ")} и $lastInterval';
}

/// Открывает Telegram с готовым сообщением для отправки.
Future<void> sendTelegramBookingMessage(String message) async {
  final url = 'https://t.me/MyZhiraf?text=${Uri.encodeComponent(message)}';
  await launchUrl(Uri.parse(url));
} 