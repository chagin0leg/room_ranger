import 'package:room_ranger/utils/date_utils.dart';
import 'package:room_ranger/utils/price_calendar_service.dart';
import 'package:room_ranger/utils/calendar_day.dart';

/// Возвращает базовую цену за день для указанной даты
int getBasePriceForDate(DateTime date) {
  return PriceCalendarService.getBasePriceForDate(date);
}

/// Рассчитывает общую стоимость для выбранных дат
int calculateTotalPrice(List<CalendarDay> days) {
  int total = 0;
  for (final day in days) {
    total += PriceCalendarService.getBasePriceForDate(day.date);
  }
  return total;
}

/// Рассчитывает итоговую стоимость с учетом скидки для каждой даты
int calculateFinalPrice(List<CalendarDay> days) {
  int total = 0;
  for (final day in days) {
    final basePrice = PriceCalendarService.getBasePriceForDate(day.date);
    final discountPercent = PriceCalendarService.getDiscountPercentForDate(day.date);
    final discount = (basePrice * discountPercent / 100).round();
    total += basePrice - discount;
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
    
    final avgPrice = daysWithPrice > 0 ? totalPrice ~/ daysWithPrice : 0;
    final monthName = getMonthName(month, GrammaticalCase.genitive);
    final currency = monthDays.isNotEmpty ? PriceCalendarService.getCurrencyForDate(monthDays.first.date) : '₽';
    
    monthInfo.add('${monthDays.length} дн. в $monthName $year (${formatPrice(avgPrice)}$currency/день)');
  }
  
  return monthInfo.join(', ');
}

/// Возвращает полную информацию о стоимости с учетом скидки
String getFullPriceInfo(List<CalendarDay> days) {
  if (days.isEmpty) return '';
  
  final basePrice = calculateTotalPrice(days);
  final finalPrice = calculateFinalPrice(days);
  final discount = basePrice - finalPrice;
  
  // Используем валюту первой даты или по умолчанию
  final currency = days.isNotEmpty 
      ? PriceCalendarService.getCurrencyForDate(days.first.date)
      : PriceCalendarService.getDefaultCurrency();
  
  // Рассчитываем средний процент скидки
  int totalDiscountPercent = 0;
  int daysWithDiscount = 0;
  for (final day in days) {
    final discountPercent = PriceCalendarService.getDiscountPercentForDate(day.date);
    if (discountPercent > 0) {
      totalDiscountPercent += discountPercent;
      daysWithDiscount++;
    }
  }
  final avgDiscountPercent = daysWithDiscount > 0 ? totalDiscountPercent ~/ daysWithDiscount : 0;
  
  return 'Стоимость: ${formatPrice(basePrice)}$currency\n'
         'Скидка $avgDiscountPercent%: -${formatPrice(discount)}$currency\n'
         'Итого: ${formatPrice(finalPrice)}$currency';
} 