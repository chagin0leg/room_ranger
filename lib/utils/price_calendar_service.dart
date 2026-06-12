import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PriceInfo {
  final int price;
  final int discount;
  final String currency;
  final bool hasPrice;

  PriceInfo({
    required this.price,
    required this.discount,
    required this.currency,
    required this.hasPrice,
  });
}

class PriceCalendarData {
  final Map<String, PriceInfo> pricesByDate;
  final int defaultDiscountPercent;
  final String defaultCurrency;

  PriceCalendarData({
    required this.pricesByDate,
    required this.defaultDiscountPercent,
    required this.defaultCurrency,
  });
}

class PriceCalendarService {
  static PriceCalendarData? _priceData;
  static bool _isLoading = false;

  static DateTime? _parseIcsDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    if (v is Map && v['dt'] != null) return DateTime.tryParse(v['dt']);
    if (v is IcsDateTime) return v.toDateTime();
    return null;
  }

  static PriceInfo _parsePriceFromSummary(String summary) {
    if (summary.isEmpty) {
      return PriceInfo(price: 0, discount: 0, currency: '₽', hasPrice: false);
    }

    // Формат: "3300₽ | 10%" или "3300 | 10%" или "3300₽" или "3300"
    final parts = summary.split('|').map((s) => s.trim()).toList();

    String pricePart = parts.isNotEmpty ? parts[0] : '';
    String discountPart = parts.length > 1 ? parts[1] : '';

    // Определяем валюту
    String currency = '₽'; // по умолчанию рубли
    if (pricePart.contains('₽')) {
      currency = '₽';
      pricePart = pricePart.replaceAll('₽', '');
    } else if (pricePart.contains('\$')) {
      currency = '\$';
      pricePart = pricePart.replaceAll('\$', '');
    }

    int price = int.tryParse(pricePart) ?? 0;
    discountPart = discountPart.replaceAll('%', '');
    int discount = int.tryParse(discountPart) ?? 0;

    return PriceInfo(
      price: price,
      discount: discount,
      currency: currency,
      hasPrice: price > 0,
    );
  }

  static String? extractIcsFileName(String url) {
    final icalMatch = RegExp(r'/ical/([0-9a-zA-Z]+)').firstMatch(url);
    if (icalMatch != null) {
      return '${icalMatch.group(1)}.ics';
    }
    final uri = Uri.parse(url);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
  }

  /// Загружает цены из ICS файла календаря
  static Future<PriceCalendarData> loadPricesFromCalendar() async {
    if (_priceData != null) return _priceData!;
    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _priceData!;
    }

    _isLoading = true;

    try {
      final url = dotenv.env['PRICES_FILE'];
      if (url == null || url.isEmpty) {
        throw Exception('PRICES_FILE not set in .env');
      }
      final fileName = extractIcsFileName(url);
      if (fileName == null) {
        throw Exception('Не удалось определить имя файла из url: $url');
      }
      final icsString = await rootBundle.loadString('assets/data/$fileName');
      final calendar = ICalendar.fromString(icsString);

      final pricesByDate = <String, PriceInfo>{};
      int defaultDiscountPercent = 10; // значение по умолчанию
      String defaultCurrency = '₽';

      for (final event in calendar.data) {
        if (event['type'] != 'VEVENT') continue;

        final summary = event['summary']?.toString() ?? '';

        // название события в формате "3300₽ | 10%"
        final priceInfo = _parsePriceFromSummary(summary);

        // Определяем даты события (может быть диапазон)
        final startDate = _parseIcsDate(event['dtstart']);
        final endDate = _parseIcsDate(event['dtend']);
        
        if (startDate != null) {
          // Если есть конечная дата, создаем цены для всех дат в диапазоне
          if (endDate != null) {
            var currentDate = startDate;
            while (currentDate.isBefore(endDate)) {
              final dateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
              pricesByDate[dateKey] = priceInfo;
              currentDate = currentDate.add(const Duration(days: 1));
            }
          } else {
            // Если нет конечной даты, создаем цену только для начальной даты
            final dateKey = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
            pricesByDate[dateKey] = priceInfo;
          }

          // Используем скидку из первого события с ценой
          if (defaultDiscountPercent == 10 && priceInfo.hasPrice) {
            defaultDiscountPercent = priceInfo.discount;
          }

          // Используем валюту из первого события с ценой
          if (defaultCurrency == '₽' && priceInfo.hasPrice) {
            defaultCurrency = priceInfo.currency;
          }
        }
      }

      _priceData = PriceCalendarData(
        pricesByDate: pricesByDate,
        defaultDiscountPercent: defaultDiscountPercent,
        defaultCurrency: defaultCurrency,
      );

      if (kDebugMode) {
        log('[PRICES] Prices loaded from calendar: ${pricesByDate.length} dates');
      }
    } catch (e) {
      if (kDebugMode) {
        log('[PRICES] Error loading prices from calendar: $e');
      }
      // Fallback на пустые цены
      _priceData = PriceCalendarData(
        pricesByDate: {},
        defaultDiscountPercent: 10,
        defaultCurrency: '₽',
      );
    } finally {
      _isLoading = false;
    }

    return _priceData!;
  }

  /// Получает цену для указанной даты
  static PriceInfo getPriceForDate(DateTime date) {
    if (_priceData == null) {
      return PriceInfo(price: 0, discount: 10, currency: '₽', hasPrice: false);
    }
    
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _priceData!.pricesByDate[dateKey] ?? 
           PriceInfo(
             price: 0, 
             discount: _priceData!.defaultDiscountPercent, 
             currency: _priceData!.defaultCurrency, 
             hasPrice: false
           );
  }

  /// Получает базовую цену для указанной даты
  static int getBasePriceForDate(DateTime date) {
    return getPriceForDate(date).price;
  }

  /// Получает процент скидки для указанной даты
  static int getDiscountPercentForDate(DateTime date) {
    return getPriceForDate(date).discount;
  }

  /// Получает валюту для указанной даты
  static String getCurrencyForDate(DateTime date) {
    return getPriceForDate(date).currency;
  }

  /// Проверяет, есть ли цена для указанной даты
  static bool hasPriceForDate(DateTime date) {
    return getPriceForDate(date).hasPrice;
  }

  /// Получает процент скидки по умолчанию
  static int getDefaultDiscountPercent() {
    return _priceData?.defaultDiscountPercent ?? 10;
  }

  /// Получает валюту по умолчанию
  static String getDefaultCurrency() {
    return _priceData?.defaultCurrency ?? '₽';
  }

  /// Перезагружает данные о ценах
  static Future<void> reloadPrices() async {
    _priceData = null;
    await loadPricesFromCalendar();
  }
}
