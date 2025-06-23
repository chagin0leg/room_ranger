import 'dart:math';

class GoogleCalendarService {
  static Future<Set<DateTime>> getBookedDates() async =>

      /// Заглушка для тестовых дат бронирования
      List.generate(
          Random().nextInt(32) + 32,
          (_) => DateTime(
                DateTime.now().year,
                Random().nextInt(12) + 1,
                Random().nextInt(28) + 1,
              )).toSet();
}
