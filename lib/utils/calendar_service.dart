import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';
import 'dart:developer';

class GoogleCalendarService {
  static const List<String> _icsUrls = [
    'https://thingproxy.freeboard.io/fetch/https://sutochno.ru/calendar/ical/bd04d8c9335677cf2d43bd99d531d142e61e45.ics',
  ];

  static DateTime? _parseIcsDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value['dt'] != null) return DateTime.tryParse(value['dt']);
    if (value is IcsDateTime) return value.toDateTime();
    return null;
  }

  static Future<Set<DateTime>> getBookedDates() async {
    Exception? lastError;
    for (final url in _icsUrls) {
      try {
        log('[ICS] Пробую загрузить календарь через: $url');
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final ical = ICalendar.fromString(response.body);
          final Set<DateTime> bookedDates = {};
          int eventCount = 0;

          for (final event in ical.data) {
            if (event['type'] == 'VEVENT') {
              eventCount++;
              final start = _parseIcsDate(event['dtstart']);
              final end = _parseIcsDate(event['dtend']) ?? start;
              log('[ICS] Event $eventCount: DTSTART=$start, DTEND=$end, SUMMARY=${event['summary']}');
              if (start != null) {
                // Добавляем все дни события
                DateTime current = DateTime(start.year, start.month, start.day);
                final last = DateTime(end!.year, end.month, end.day);
                while (current.isBefore(last)) {
                  bookedDates.add(current);
                  log('[ICS]   -> Add booked: ${current.toIso8601String().substring(0, 10)}');
                  current = current.add(const Duration(days: 1));
                }
              }
            }
          }
          log('[ICS] Всего событий: $eventCount, всего занятых дней: ${bookedDates.length}');
          return bookedDates;
        } else {
          log('[ICS] Ошибка загрузки ICS через $url: ${response.statusCode}');
          lastError = Exception('Ошибка загрузки ICS: ${response.statusCode}');
        }
      } catch (e) {
        log('[ICS] Ошибка при попытке через $url: $e');
        lastError = Exception('Ошибка при попытке через $url: $e');
      }
    }
    throw lastError ?? Exception('Не удалось загрузить ICS через все прокси');
  }
}
