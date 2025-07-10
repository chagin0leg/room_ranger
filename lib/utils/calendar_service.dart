import 'dart:async';
import 'dart:developer';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CalendarService {
  static Map<int, List<String>>? _cachedCalendars;
  static Map<int, List<String>> get _roomCalendars {
    if (_cachedCalendars != null) return _cachedCalendars!;
    final files = dotenv.env['ICS_FILES'];
    if (files == null || files.isEmpty) return {};
    final urls = files
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.endsWith('.ics'))
        .toList();
    final Map<int, List<String>> result = {};
    for (int i = 0; i < urls.length; i++) {
      result[i + 1] = [urls[i]];
    }
    _cachedCalendars = result;
    return result;
  }

  static String? extractIcsFileName(String url) {
    final icalMatch = RegExp(r'/ical/([0-9a-zA-Z]+)').firstMatch(url);
    if (icalMatch != null) {
      return '${icalMatch.group(1)}.ics';
    }
    final uri = Uri.parse(url);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
  }

  static DateTime? _parseIcsDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    if (v is Map && v['dt'] != null) return DateTime.tryParse(v['dt']);
    if (v is IcsDateTime) return v.toDateTime();
    return null;
  }

  static Future<List<DateTime>> getBookedDates(int roomNumber) async {
    final calendarUrls = _roomCalendars[roomNumber];
    if (calendarUrls == null) {
      throw Exception('Unknown room number: $roomNumber');
    }
    if (calendarUrls.isEmpty) {
      log('[ICS] Room $roomNumber has no calendar - all dates considered booked');
      return _getAllDatesAsBookedList();
    }
    final fileName = extractIcsFileName(calendarUrls.first);
    if (fileName == null) {
      throw Exception('Failed to determine file name from url: ${calendarUrls.first}');
    }
    final filePath = 'assets/data/$fileName';
    final assetResult = await _tryLoadCalendarFromAsset(filePath, roomNumber);
    if (assetResult != null) {
      log('[ICS] Room $roomNumber: Successfully loaded calendar from asset');
      // Группируем по groupId и вычисляем position
      return _withPositions(assetResult);
    }
    log('[ICS] Room $roomNumber: Failed to load calendar from asset - all dates considered booked');
    final allBookedDates = _getAllDatesAsBookedList();
    log('[ICS] Room $roomNumber: Returning all dates as booked (${allBookedDates.length} days)');
    return allBookedDates;
  }

  static Future<List<DateTime>?> _tryLoadCalendarFromAsset(
      String assetPath, int roomNumber) async {
    try {
      log('[ICS] Room $roomNumber: Trying to load calendar from asset: $assetPath');
      String icsContent;
      try {
        icsContent = await rootBundle.loadString(assetPath);
      } catch (e) {
        log('[ICS] Room $roomNumber: Asset does not exist: $assetPath');
        return null;
      }
      final calendar = ICalendar.fromString(icsContent);
      final List<DateTime> bookedDays = [];
      int eventCount = 0;
      for (final event in calendar.data) {
        if (event['type'] == 'VEVENT') {
          eventCount++;
          final start = _parseIcsDate(event['dtstart']);
          final end = _parseIcsDate(event['dtend']) ?? start;
          log('[ICS] Room $roomNumber, Event $eventCount: DTSTART=$start, DTEND=$end, SUMMARY=${event['summary']}');
          if (start != null) {
            DateTime current = DateTime(start.year, start.month, start.day);
            final last = DateTime(end!.year, end.month, end.day);
            while (current.isBefore(last)) {
              bookedDays.add(current); // временно single
              current = current.add(const Duration(days: 1));
            }
          }
        }
      }
      // После сбора всех дат пересчитываем позиции
      return bookedDays;
    } catch (e) {
      log('[ICS] Room $roomNumber: Error loading from asset $assetPath: $e');
      return null;
    }
  }

  static List<DateTime> _getAllDatesAsBookedList() {
    final List<DateTime> allDates = [];
    final now = DateTime.now();
    final endYear = now.year + 2;
    DateTime current = DateTime(now.year, 1, 1);
    final end = DateTime(endYear, 12, 31);
    log('[ICS] Generating all dates as booked from ${current.toIso8601String().substring(0, 10)} to ${end.toIso8601String().substring(0, 10)}');
    while (current.isBefore(end)) {
      allDates.add(current); // временно single
      current = current.add(const Duration(days: 1));
    }
    // После сбора всех дат пересчитываем позиции
    return allDates;
  }

  /// Группирует по groupId и вычисляет position для каждой даты
  static List<DateTime> _withPositions(List<DateTime> days) {
    final Map<String, List<DateTime>> groups = {};
    for (final d in days) {
      groups.putIfAbsent(d.toIso8601String().substring(0, 10), () => []).add(d);
    }
    final result = <DateTime>[];
    for (final entry in groups.entries) {
      result.addAll(entry.value);
    }
    return result;
  }

  static List<int> getAvailableRooms() => _roomCalendars.keys.toList();
}
