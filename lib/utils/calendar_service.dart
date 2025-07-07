import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';
import 'dart:developer';
import 'dart:async';

class GoogleCalendarService {
  // Календари для каждой комнаты (номер комнаты -> URL календаря)
  static const Map<int, List<String>> _roomCalendars = {
    1: ['https://sutochno.ru/calendar/ical/bd04d8c9335677cf2d43bd99d531d142e61e45.ics'],
    2: ['https://sutochno.ru/calendar/ical/84214dde436a8dc4a443bdf5cb309110af06e4.ics'],
    3: ['https://sutochno.ru/calendar/ical/4085bd43645d78f472df22248e4566214771a88.ics'],
    4: ['https://sutochno.ru/calendar/ical/7888d77a5bb2e094a5df222861fec42275d4494.ics'],
  };

  // Список прокси-серверов для обхода CORS
  static const List<String> _proxyServers = [
    'https://api.allorigins.win/raw?url=',
    'https://cors-anywhere.herokuapp.com/',
    'https://thingproxy.freeboard.io/fetch/',
  ];

  static DateTime? _parseIcsDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value['dt'] != null) return DateTime.tryParse(value['dt']);
    if (value is IcsDateTime) return value.toDateTime();
    return null;
  }

  /// Получает первый успешный результат из списка futures (аналог Promise.race, но только для успешных)
  static Future<T?> firstSuccessful<T>(Iterable<Future<T?>> futures) async {
    final completer = Completer<T?>();
    int completed = 0;
    for (final future in futures) {
      future.then((value) {
        if (value != null && !completer.isCompleted) {
          completer.complete(value);
        } else {
          completed++;
          if (completed == futures.length && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }).catchError((_) {
        completed++;
        if (completed == futures.length && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }
    return completer.future;
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

    // Создаем список всех URL для параллельного запроса
    final originalUrl = calendarUrls.first;
    final urlsToTry = [originalUrl, ..._proxyServers.map((proxy) => '$proxy$originalUrl')];
    
    // Выполняем все запросы параллельно, но используем первый успешный
    final result = await firstSuccessful(urlsToTry.map((url) => _tryLoadCalendar(url, roomNumber)));
    if (result != null) {
      log('[ICS] Комната $roomNumber: Успешно загружен календарь через один из источников');
      return result;
    }
    // Если ни один запрос не удался, считаем комнату занятой
    log('[ICS] Комната $roomNumber: Не удалось загрузить календарь ни через один источник - считаем все даты занятыми');
    final allBookedDates = _getAllDatesAsBooked();
    log('[ICS] Комната $roomNumber: Возвращаем все даты как занятые (${allBookedDates.length} дней)');
    return allBookedDates;
  }

  /// Пытается загрузить календарь по указанному URL
  static Future<Set<DateTime>?> _tryLoadCalendar(String url, int roomNumber) async {
    try {
      log('[ICS] Комната $roomNumber: Пробую загрузить календарь через: $url');
      
      final headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/calendar, text/plain, */*',
        'Accept-Language': 'ru-RU,ru;q=0.9,en;q=0.8',
        'Origin': 'https://chagin0leg.github.io',
        'Referer': 'https://chagin0leg.github.io/',
      };
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      
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
        
        // Логируем все занятые даты
        final sortedDates = bookedDates.toList()..sort((a, b) => a.compareTo(b));
        log('[ICS] Комната $roomNumber: Все занятые даты:');
        for (final date in sortedDates) {
          log('[ICS] Комната $roomNumber:   ${date.toIso8601String().substring(0, 10)}');
        }
        
        return bookedDates;
      } else {
        log('[ICS] Комната $roomNumber: Ошибка загрузки ICS через $url: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('[ICS] Комната $roomNumber: Ошибка при попытке через $url: $e');
      if (e.toString().contains('CORS')) {
        log('[ICS] Комната $roomNumber: Обнаружена CORS ошибка');
      }
      return null;
    }
  }

  /// Возвращает все даты как занятые (для комнат без календаря)
  static Set<DateTime> _getAllDatesAsBooked() {
    final Set<DateTime> allDates = {};
    final now = DateTime.now();
    final endYear = now.year + 2; // На 2 года вперед
    
    DateTime current = DateTime(now.year, 1, 1);
    final end = DateTime(endYear, 12, 31);
    
    log('[ICS] Генерируем все даты как занятые с ${current.toIso8601String().substring(0, 10)} по ${end.toIso8601String().substring(0, 10)}');
    
    while (current.isBefore(end)) {
      allDates.add(current);
      current = current.add(const Duration(days: 1));
    }
    
    log('[ICS] Сгенерировано ${allDates.length} занятых дат');
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
