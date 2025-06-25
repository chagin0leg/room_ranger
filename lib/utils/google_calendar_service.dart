import 'dart:math';

import 'package:flutter/foundation.dart';

class GoogleCalendarService {
  static Future<Set<DateTime>> getBookedDates() async {
    if (kDebugMode) {
      return List.generate(
          Random().nextInt(32) + 32,
          (_) => DateTime(
                DateTime.now().year,
                Random().nextInt(12) + 1,
                Random().nextInt(28) + 1,
              )).toSet();
    }
    return List<DateTime>.empty().toSet();
  }
}
