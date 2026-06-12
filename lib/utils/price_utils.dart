import 'package:room_ranger/utils/date_utils.dart';
import 'package:room_ranger/utils/price_calendar_service.dart';
import 'package:room_ranger/utils/calendar_day.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer';

/// Возвращает базовую цену за день для указанной даты
int getBasePriceForDate(DateTime date) {
  return PriceCalendarService.getBasePriceForDate(date);
}

/// Рассчитывает общую стоимость для выбранных дат (по ночам)
int calculateTotalPrice(List<CalendarDay> days) {
  if (days.isEmpty) return 0;
  
  // Сортируем дни по дате
  final sortedDays = List<CalendarDay>.from(days)..sort((a, b) => a.date.compareTo(b.date));
  
  // Группируем дни в непрерывные отрезки
  final intervals = <List<CalendarDay>>[];
  if (sortedDays.isNotEmpty) {
    var currentInterval = <CalendarDay>[sortedDays.first];
    for (int i = 1; i < sortedDays.length; i++) {
      final prev = sortedDays[i - 1];
      final curr = sortedDays[i];
      if (curr.date.difference(prev.date).inDays == 1) {
        currentInterval.add(curr);
      } else {
        intervals.add(List.from(currentInterval));
        currentInterval = [curr];
      }
    }
    intervals.add(currentInterval);
  }
  
  // Рассчитываем стоимость для каждого интервала отдельно
  int total = 0;
  for (final interval in intervals) {
    for (int i = 0; i < interval.length - 1; i++) {
      total += PriceCalendarService.getBasePriceForDate(interval[i].date);
    }
  }
  return total;
}

/// Рассчитывает итоговую стоимость с учетом скидки для каждой ночи
int calculateFinalPrice(List<CalendarDay> days) {
  if (days.isEmpty) return 0;
  
  // Сортируем дни по дате
  final sortedDays = List<CalendarDay>.from(days)..sort((a, b) => a.date.compareTo(b.date));
  
  // Группируем дни в непрерывные отрезки
  final intervals = <List<CalendarDay>>[];
  if (sortedDays.isNotEmpty) {
    var currentInterval = <CalendarDay>[sortedDays.first];
    for (int i = 1; i < sortedDays.length; i++) {
      final prev = sortedDays[i - 1];
      final curr = sortedDays[i];
      if (curr.date.difference(prev.date).inDays == 1) {
        currentInterval.add(curr);
      } else {
        intervals.add(List.from(currentInterval));
        currentInterval = [curr];
      }
    }
    intervals.add(currentInterval);
  }
  
  // Рассчитываем стоимость для каждого интервала отдельно
  int total = 0;
  for (final interval in intervals) {
    for (int i = 0; i < interval.length - 1; i++) {
      final basePrice = PriceCalendarService.getBasePriceForDate(interval[i].date);
      final discountPercent = PriceCalendarService.getDiscountPercentForDate(interval[i].date);
      final discount = (basePrice * discountPercent / 100).round();
      total += basePrice - discount;
    }
  }
  return total;
}

/// Форматирует цену с разделителями тысяч
String formatPrice(int price) {
  return price.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match match) => '${match[1]} ',
  );
}

/// Возвращает текст с информацией о ценах для выбранных дат
String getPriceInfoText(List<CalendarDay> days) {
  if (days.isEmpty) return '';
  
  // Группируем даты по месяцам и годам
  final Map<String, List<CalendarDay>> daysPerYearMonth = {};
  for (final day in days) {
    final key = '${day.date.year}-${day.date.month}';
    daysPerYearMonth.putIfAbsent(key, () => []).add(day);
  }
  
  // Формируем список месяцев с количеством дней и средней ценой
  final List<String> monthInfo = [];
  for (final entry in daysPerYearMonth.entries) {
    final parts = entry.key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthDays = entry.value;
    
    // Рассчитываем среднюю цену для этого месяца
    int totalPrice = 0;
    int daysWithPrice = 0;
    for (final day in monthDays) {
      final price = PriceCalendarService.getBasePriceForDate(day.date);
      if (price > 0) {
        totalPrice += price;
        daysWithPrice++;
      }
    }
    
    final nights = monthDays.length > 1 ? monthDays.length - 1 : 0;
    final avgPrice = daysWithPrice > 0 ? totalPrice ~/ daysWithPrice : 0;
    final monthName = getMonthName(month, GrammaticalCase.genitive);
    final currency = monthDays.isNotEmpty ? PriceCalendarService.getCurrencyForDate(monthDays.first.date) : '₽';
    
    if (nights > 0) {
      monthInfo.add('$nights ${getNightWord(nights)} в $monthName $year (${formatPrice(avgPrice)}$currency/ночь)');
    }
  }
  
  return monthInfo.join(', ');
}

/// Возвращает полную информацию о стоимости с учетом скидки
String getFullPriceInfo(List<CalendarDay> days, {Map<int, List<CalendarDay>>? daysByRoom}) {
  if (days.isEmpty) return '';
  
  // Группируем дни по номерам комнат
  final Map<int, List<CalendarDay>> daysByRoomGroup = {};
  
  if (daysByRoom != null) {
    // Используем переданную группировку по номерам
    for (final entry in daysByRoom.entries) {
      final roomNumber = entry.key;
      final roomDays = entry.value.where((d) => d.status == DayStatus.selected).toList();
      if (roomDays.isNotEmpty) {
        daysByRoomGroup[roomNumber] = roomDays;
      }
    }
  } else {
    // Fallback: группируем по groupId (старая логика)
    final Map<String, List<CalendarDay>> daysByGroup = {};
    for (final day in days) {
      if (day.groupId != null) {
        daysByGroup.putIfAbsent(day.groupId!, () => []).add(day);
      }
    }
    
    if (daysByGroup.isNotEmpty) {
      // Используем первый groupId как номер комнаты 1
      daysByRoomGroup[1] = daysByGroup.values.first;
    } else {
      daysByRoomGroup[1] = days;
    }
  }
  
  // Рассчитываем стоимость для каждого номера отдельно
  int totalBasePrice = 0;
  int totalFinalPrice = 0;
  int totalNights = 0;
  int totalDiscountPercent = 0;
  int totalNightsWithDiscount = 0;
  
  for (final entry in daysByRoomGroup.entries) {
    final roomNumber = entry.key;
    final groupDays = entry.value;
    final sortedDays = List<CalendarDay>.from(groupDays)..sort((a, b) => a.date.compareTo(b.date));
    
    // Группируем дни в непрерывные отрезки и считаем ночи для каждого
    final intervals = <List<CalendarDay>>[];
    if (sortedDays.isNotEmpty) {
      var currentInterval = <CalendarDay>[sortedDays.first];
      for (int i = 1; i < sortedDays.length; i++) {
        final prev = sortedDays[i - 1];
        final curr = sortedDays[i];
        if (curr.date.difference(prev.date).inDays == 1) {
          currentInterval.add(curr);
        } else {
          intervals.add(List.from(currentInterval));
          currentInterval = [curr];
        }
      }
      intervals.add(currentInterval);
    }
    
    // Считаем общее количество ночей для этого номера
    int totalNightsRoom = 0;
    for (final interval in intervals) {
      final intervalNights = interval.length > 1 ? interval.length - 1 : 0;
      totalNightsRoom += intervalNights;
    }
    
    if (kDebugMode) {
      log('[PRICE] Room $roomNumber: ${intervals.length} intervals, $totalNightsRoom total nights');
      for (int i = 0; i < intervals.length; i++) {
        final interval = intervals[i];
        final nights = interval.length > 1 ? interval.length - 1 : 0;
        log('[PRICE]   Interval $i: ${interval.length} days = $nights nights');
      }
    }
    
    if (totalNightsRoom > 0) {
      // Рассчитываем стоимость для этого номера
      int groupBasePrice = 0;
      int groupFinalPrice = 0;
      int groupDiscountPercent = 0;
      int groupNightsWithDiscount = 0;
      
      // Рассчитываем стоимость для каждого интервала отдельно
      for (final interval in intervals) {
        for (int i = 0; i < interval.length - 1; i++) {
          final basePrice = PriceCalendarService.getBasePriceForDate(interval[i].date);
          final discountPercent = PriceCalendarService.getDiscountPercentForDate(interval[i].date);
          final discount = (basePrice * discountPercent / 100).round();
          
          groupBasePrice += basePrice;
          groupFinalPrice += basePrice - discount;
          
          if (discountPercent > 0) {
            groupDiscountPercent += discountPercent;
            groupNightsWithDiscount++;
          }
        }
      }
      
      totalBasePrice += groupBasePrice;
      totalFinalPrice += groupFinalPrice;
      totalNights += totalNightsRoom; // Добавляем количество ночей для этого номера
      totalDiscountPercent += groupDiscountPercent;
      totalNightsWithDiscount += groupNightsWithDiscount;
    }
  }
  

  
  if (totalNights == 0) {
    return 'Выберите даты для расчета стоимости';
  }
  
  final discount = totalBasePrice - totalFinalPrice;
  final avgDiscountPercent = totalNightsWithDiscount > 0 ? totalDiscountPercent ~/ totalNightsWithDiscount : 0;
  
  // Используем валюту первой даты или по умолчанию
  final currency = days.isNotEmpty 
      ? PriceCalendarService.getCurrencyForDate(days.first.date)
      : PriceCalendarService.getDefaultCurrency();
  
  return 'Стоимость за $totalNights ${getNightWord(totalNights)}: ${formatPrice(totalBasePrice)}$currency\n'
         'Скидка $avgDiscountPercent%: -${formatPrice(discount)}$currency\n'
         'Итого: ${formatPrice(totalFinalPrice)}$currency';
} 