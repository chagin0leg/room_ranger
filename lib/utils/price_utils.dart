import 'package:room_ranger/utils/date_utils.dart';

/// Возвращает базовую цену за день для указанного месяца
int getBasePriceForMonth(int month) {
  switch (month) {
    case 7: // Июль
      return 3300;
    case 8: // Август
      return 3800;
    case 9: // Сентябрь
      return 2700;
    case 10: // Октябрь
    case 11: // Ноябрь
    case 12: // Декабрь
      return 1800;
    default:
      return 1800; // Цена по умолчанию для остальных месяцев
  }
}

/// Возвращает название месяца с ценой
String getMonthWithPrice(int month) {
  final price = getBasePriceForMonth(month);
  final monthName = getMonthName(month, GrammaticalCase.nominative);
  return '$monthName ${price.toStringAsFixed(0)}₽';
}

/// Рассчитывает общую стоимость для выбранных дат
int calculateTotalPrice(List<DateTime> dates) {
  int total = 0;
  for (final date in dates) {
    total += getBasePriceForMonth(date.month);
  }
  return total;
}

/// Рассчитывает итоговую стоимость с учетом скидки 10%
int calculateFinalPrice(List<DateTime> dates) {
  final basePrice = calculateTotalPrice(dates);
  final discount = (basePrice * 0.1).round();
  return basePrice - discount;
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
  
  // Группируем даты по месяцам
  final Map<int, int> daysPerMonth = {};
  for (final date in dates) {
    daysPerMonth[date.month] = (daysPerMonth[date.month] ?? 0) + 1;
  }
  
  // Формируем список месяцев с количеством дней
  final List<String> monthInfo = [];
  for (final entry in daysPerMonth.entries) {
    final month = entry.key;
    final days = entry.value;
    final price = getBasePriceForMonth(month);
    final monthName = getMonthName(month, GrammaticalCase.genitive);
    monthInfo.add('$days дн. в $monthName (${formatPrice(price)}₽/день)');
  }
  
  return monthInfo.join(', ');
}

/// Возвращает полную информацию о стоимости с учетом скидки
String getFullPriceInfo(List<DateTime> dates) {
  if (dates.isEmpty) return '';
  
  final basePrice = calculateTotalPrice(dates);
  final finalPrice = calculateFinalPrice(dates);
  final discount = basePrice - finalPrice;
  
  return 'Стоимость: ${formatPrice(basePrice)}₽\n'
         'Скидка 10%: -${formatPrice(discount)}₽\n'
         'Итого: ${formatPrice(finalPrice)}₽';
} 