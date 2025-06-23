import 'dart:math';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';

class GoogleCalendarService {
  static const _scopes = [calendar.CalendarApi.calendarReadonlyScope];
  static const _credentials = {
    "type": "service_account",
    "project_id": "YOUR_PROJECT_ID",
    "private_key_id": "YOUR_PRIVATE_KEY_ID",
    "private_key": "YOUR_PRIVATE_KEY",
    "client_email": "YOUR_CLIENT_EMAIL",
    "client_id": "YOUR_CLIENT_ID",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "YOUR_CERT_URL"
  };

  static Future<Set<DateTime>> getBookedDates() async {
    /// Заглушка для тестовых дат бронирования
    final now = DateTime.now();
    return {
      for (var i = 0; i < 64; i++)
        DateTime(now.year, Random().nextInt(12) + 1, Random().nextInt(28) + 1),
    };

    // /// Реальная интеграция с Google Calendar
    // final credentials = ServiceAccountCredentials.fromJson(_credentials);
    // final client = await clientViaServiceAccount(credentials, _scopes);
    // final calendarApi = calendar.CalendarApi(client);

    // final now = DateTime.now();
    // final startOfMonth = DateTime(now.year, now.month, 1);
    // final endOfMonth = DateTime(now.year, now.month + 1, 0);

    // final events = await calendarApi.events.list(
    //   'primary',
    //   timeMin: startOfMonth.toUtc(),
    //   timeMax: endOfMonth.toUtc(),
    //   singleEvents: true,
    //   orderBy: 'startTime',
    // );

    // final bookedDates = <DateTime>{};
    // for (var event in events.items ?? []) {
    //   if (event.start?.dateTime != null) {
    //     bookedDates.add(event.start!.dateTime!.toLocal());
    //   }
    // }

    // return bookedDates;
  }
}
