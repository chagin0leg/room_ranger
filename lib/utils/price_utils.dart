import 'package:room_ranger/utils/date_utils.dart';
import 'package:room_ranger/utils/price_calendar_service.dart';

/// Возвращает базовую цену за день для указанной даты
int getBasePriceForDate(DateTime date) {
  return PriceCalendarService.getBasePriceForDate(date);
}

/// Рассчитывает общую стоимость для выбранных дат
int calculateTotalPrice(List<DateTime> dates) {
  int total = 0;
  for (final date in dates) {
    total += getBasePriceForDate(date);
  }
  return total;
}

/// Рассчитывает итоговую стоимость с учетом скидки для каждой даты
int calculateFinalPrice(List<DateTime> dates) {
  int total = 0;
  for (final date in dates) {
    final basePrice = getBasePriceForDate(date);
    final discountPercent = PriceCalendarService.getDiscountPercentForDate(date);
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
String getPriceInfoText(List<DateTime> dates) {
  if (dates.isEmpty) return '';
  
  // Группируем даты по месяцам и годам
  final Map<String, List<DateTime>> datesPerYearMonth = {};
  for (final date in dates) {
    final key = '${date.year}-${date.month}';
    datesPerYearMonth.putIfAbsent(key, () => []).add(date);
  }
  
  // Формируем список месяцев с количеством дней и средней ценой
  final List<String> monthInfo = [];
  for (final entry in datesPerYearMonth.entries) {
    final parts = entry.key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final dates = entry.value;
    
    // Рассчитываем среднюю цену для этого месяца
    int totalPrice = 0;
    int daysWithPrice = 0;
    for (final date in dates) {
      final price = getBasePriceForDate(date);
      if (price > 0) {
        totalPrice += price;
        daysWithPrice++;
      }
    }
    
    final avgPrice = daysWithPrice > 0 ? totalPrice ~/ daysWithPrice : 0;
    final monthName = getMonthName(month, GrammaticalCase.genitive);
    final currency = dates.isNotEmpty ? PriceCalendarService.getCurrencyForDate(dates.first) : '₽';
    
    monthInfo.add('${dates.length} дн. в $monthName $year (${formatPrice(avgPrice)}$currency/день)');
  }
  
  return monthInfo.join(', ');
}

/// Возвращает полную информацию о стоимости с учетом скидки
String getFullPriceInfo(List<DateTime> dates) {
  if (dates.isEmpty) return '';
  
  final basePrice = calculateTotalPrice(dates);
  final finalPrice = calculateFinalPrice(dates);
  final discount = basePrice - finalPrice;
  
  // Используем валюту первой даты или по умолчанию
  final currency = dates.isNotEmpty 
      ? PriceCalendarService.getCurrencyForDate(dates.first)
      : PriceCalendarService.getDefaultCurrency();
  
  // Рассчитываем средний процент скидки
  int totalDiscountPercent = 0;
  int daysWithDiscount = 0;
  for (final date in dates) {
    final discountPercent = PriceCalendarService.getDiscountPercentForDate(date);
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