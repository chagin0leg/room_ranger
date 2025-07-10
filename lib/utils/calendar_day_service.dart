import 'calendar_day.dart';
import 'package:room_ranger/utils/price_calendar_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CalendarDayService {
  /// Генерирует Map<room, List<CalendarDay>> для всех комнат
  static Map<int, List<CalendarDay>> generateForAllRooms({
    required List<int> rooms,
    required DateTime from,
    required DateTime to,
    required Map<int, Set<DateTime>> bookedDates,
    required Map<int, Set<DateTime>> selectedDates,
  }) {
    final result = <int, List<CalendarDay>>{};
    for (final room in rooms) {
      result[room] = generateForRoom(
        from: from,
        to: to,
        booked: bookedDates[room] ?? {},
        selected: selectedDates[room] ?? {},
      );
    }
    return result;
  }

  /// Генерирует список CalendarDay для одной комнаты
  static List<CalendarDay> generateForRoom({
    required DateTime from,
    required DateTime to,
    required Set<DateTime> booked,
    required Set<DateTime> selected,
  }) {
    final days = <CalendarDay>[];
    DateTime current = from;
    while (!current.isAfter(to)) {
      final isPast = current.isBefore(DateTime.now());
      final hasPrice = PriceCalendarService.hasPriceForDate(current);
      final priceInfo = PriceCalendarService.getPriceForDate(current);
      DayStatus status;
      if (booked.contains(current)) {
        status = DayStatus.booked;
      } else if (selected.contains(current)) {
        status = DayStatus.selected;
      } else if (isPast || !hasPrice) {
        status = DayStatus.unavailable;
      } else {
        status = DayStatus.free;
      }
      days.add(CalendarDay(
        date: current,
        status: status,
        price: priceInfo.price > 0 ? priceInfo.price : null,
        discount: priceInfo.discount > 0 ? priceInfo.discount : null,
        currency: priceInfo.currency,
        // position и groupId будут заполнены ниже
      ));
      current = current.add(const Duration(days: 1));
    }
    // После генерации дней вычисляем позиции и groupId для booked и selected
    applyGroupPositions(days, DayStatus.booked);
    applyGroupPositions(days, DayStatus.selected);
    return days;
  }

  /// Вычисляет позиции и groupId для дней с указанным статусом
  static void applyGroupPositions(List<CalendarDay> days, DayStatus status) {
    // Группируем последовательные дни
    final groupList = <List<int>>[]; // индексы в days
    List<int> currentGroup = [];
    for (int i = 0; i < days.length; i++) {
      if (days[i].status == status) {
        if (currentGroup.isEmpty ||
            days[i].date.difference(days[currentGroup.last].date).inDays == 1) {
          currentGroup.add(i);
        } else {
          groupList.add(List.from(currentGroup));
          currentGroup = [i];
        }
      } else if (currentGroup.isNotEmpty) {
        groupList.add(List.from(currentGroup));
        currentGroup = [];
      }
    }
    if (currentGroup.isNotEmpty) groupList.add(currentGroup);
    // Проставляем позиции и groupId
    for (final group in groupList) {
      final groupId =
          '${status.name}_${days[group.first].date.toIso8601String()}';
      for (int j = 0; j < group.length; j++) {
        final idx = group[j];
        DayPosition pos;
        if (group.length == 1) {
          pos = DayPosition.single;
        } else if (j == 0) {
          pos = DayPosition.start;
        } else if (j == group.length - 1) {
          pos = DayPosition.end;
        } else {
          pos = DayPosition.middle;
        }
        days[idx] = days[idx].copyWith(position: pos, groupId: groupId);
      }
    }
  }

  /// Получает минимальное количество ночей из переменных окружения
  static int getMinNights() {
    return int.tryParse(dotenv.env['MIN_NIGHTS'] ?? '4') ?? 4;
  }

  /// Обновляет статусы выбранных дней с учетом минимального количества ночей
  static void updateSelectedDaysWithMinNights(Map<int, List<CalendarDay>> daysByRoom) {
    final minNights = getMinNights();
    
    for (final entry in daysByRoom.entries) {
      final roomDays = entry.value;
      final selectedGroups = <String, List<CalendarDay>>{};
      
      // Группируем выбранные дни по groupId
      for (final day in roomDays) {
        if (day.status == DayStatus.selected && day.groupId != null) {
          selectedGroups.putIfAbsent(day.groupId!, () => []).add(day);
        }
      }
      
      // Проверяем каждую группу на соответствие минимальному количеству ночей
      for (final group in selectedGroups.values) {
        final nights = group.length;
        final newStatus = nights >= minNights ? DayStatus.selected : DayStatus.insufficientNights;
        
        // Обновляем статусы всех дней в группе
        for (final day in group) {
          final dayIndex = roomDays.indexWhere((d) => d.date == day.date);
          if (dayIndex != -1) {
            roomDays[dayIndex] = roomDays[dayIndex].copyWith(status: newStatus);
          }
        }
      }
    }
  }
}
