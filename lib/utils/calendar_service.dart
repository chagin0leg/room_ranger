import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';
import 'dart:developer';

class GoogleCalendarService {
  // Календари для каждой комнаты (номер комнаты -> URL календаря)
  static const Map<int, List<String>> _roomCalendars = {
    1: [], // Комната 1 - нет календаря, всегда занята
    2: [
      'https://thingproxy.freeboard.io/fetch/https://sutochno.ru/calendar/ical/bd04d8c9335677cf2d43bd99d531d142e61e45.ics',
    ], // Комната 2 - есть календарь
    3: [], // Комната 3 - нет календаря, всегда занята
    4: [], // Комната 4 - нет календаря, всегда занята
  };

  static DateTime? _parseIcsDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value['dt'] != null) return DateTime.tryParse(value['dt']);
    if (value is IcsDateTime) return value.toDateTime();
    return null;
  }

  /// Получает занятые даты для конкретной комнаты
  static Future<Set<DateTime>> getBookedDates(int roomNumber) async {
    // Проверяем, есть ли календарь для этой комнаты
    final calendarUrls = _roomCalendars[roomNumber];
    if (calendarUrls == null) {
      throw Exception('Неизвестный номер комнаты: $roomNumber');
    }

    // Если у комнаты нет календаря, возвращаем все даты как занятые
    if (calendarUrls.isEmpty) {
      log('[ICS] Комната $roomNumber не имеет календаря - считаем все даты занятыми');
      return _getAllDatesAsBooked();
    }

    // Загружаем календарь для комнаты
    Exception? lastError;
    for (final url in calendarUrls) {
      try {
        log('[ICS] Комната $roomNumber: Пробую загрузить календарь через: $url');
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
              log('[ICS] Комната $roomNumber, Event $eventCount: DTSTART=$start, DTEND=$end, SUMMARY=${event['summary']}');
              if (start != null) {
                // Добавляем все дни события
                DateTime current = DateTime(start.year, start.month, start.day);
                final last = DateTime(end!.year, end.month, end.day);
                while (current.isBefore(last)) {
                  bookedDates.add(current);
                  log('[ICS] Комната $roomNumber -> Add booked: ${current.toIso8601String().substring(0, 10)}');
                  current = current.add(const Duration(days: 1));
                }
              }
            }
          }
          log('[ICS] Комната $roomNumber: Всего событий: $eventCount, всего занятых дней: ${bookedDates.length}');
          return bookedDates;
        } else {
          log('[ICS] Комната $roomNumber: Ошибка загрузки ICS через $url: ${response.statusCode}');
          lastError = Exception('Ошибка загрузки ICS: ${response.statusCode}');
        }
      } catch (e) {
        log('[ICS] Комната $roomNumber: Ошибка при попытке через $url: $e');
        lastError = Exception('Ошибка при попытке через $url: $e');
      }
    }
    throw lastError ?? Exception('Не удалось загрузить ICS для комнаты $roomNumber');
  }

  /// Возвращает все даты как занятые (для комнат без календаря)
  static Set<DateTime> _getAllDatesAsBooked() {
    final Set<DateTime> allDates = {};
    final now = DateTime.now();
    final endYear = now.year + 2; // На 2 года вперед
    
    DateTime current = DateTime(now.year, 1, 1);
    final end = DateTime(endYear, 12, 31);
    
    while (current.isBefore(end)) {
      allDates.add(current);
      current = current.add(const Duration(days: 1));
    }
    
    return allDates;
  }

  /// Получает список доступных комнат
  static List<int> getAvailableRooms() {
    return _roomCalendars.keys.toList();
  }

  /// Проверяет, есть ли календарь для комнаты
  static bool hasCalendar(int roomNumber) {
    final urls = _roomCalendars[roomNumber];
    return urls != null && urls.isNotEmpty;
  }
}
