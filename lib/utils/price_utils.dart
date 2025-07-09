import 'package:room_ranger/utils/date_utils.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Возвращает базовую цену за день для указанного месяца
int getBasePriceForMonth(int month) {
  final priceMap = {
    1: dotenv.env['PRICE_JANUARY'] ?? '',
    2: dotenv.env['PRICE_FEBRUARY'] ?? '',
    3: dotenv.env['PRICE_MARCH'] ?? '',
    4: dotenv.env['PRICE_APRIL'] ?? '',
    5: dotenv.env['PRICE_MAY'] ?? '',
    6: dotenv.env['PRICE_JUNE'] ?? '',
    7: dotenv.env['PRICE_JULY'] ?? '',
    8: dotenv.env['PRICE_AUGUST'] ?? '',
    9: dotenv.env['PRICE_SEPTEMBER'] ?? '',
    10: dotenv.env['PRICE_OCTOBER'] ?? '',
    11: dotenv.env['PRICE_NOVEMBER'] ?? '',
    12: dotenv.env['PRICE_DECEMBER'] ?? '',
  };
  
  return int.tryParse(priceMap[month] ?? '') ?? 0;
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

/// Рассчитывает итоговую стоимость с учетом скидки
int calculateFinalPrice(List<DateTime> dates) {
  final basePrice = calculateTotalPrice(dates);
  final discountPercent = int.tryParse(dotenv.env['DISCOUNT_PERCENT'] ?? '0') ?? 0;
  final discount = (basePrice * discountPercent / 100).round();
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
  final currency = dotenv.env['CURRENCY'];
  final discountPercent = int.tryParse(dotenv.env['DISCOUNT_PERCENT'] ?? '0') ?? 0;
  
  return 'Стоимость: ${formatPrice(basePrice)}$currency\n'
         'Скидка $discountPercent%: -${formatPrice(discount)}$currency\n'
         'Итого: ${formatPrice(finalPrice)}$currency';
} 