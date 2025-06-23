import 'dart:math';

import 'package:flutter/material.dart';
import 'package:room_ranger/utils/date_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';

class CalendarService {
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
    final credentials = ServiceAccountCredentials.fromJson(_credentials);
    final client = await clientViaServiceAccount(credentials, _scopes);
    final calendarApi = calendar.CalendarApi(client);

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final events = await calendarApi.events.list(
      'primary',
      timeMin: startOfMonth.toUtc(),
      timeMax: endOfMonth.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );

    final bookedDates = <DateTime>{};
    for (var event in events.items ?? []) {
      if (event.start?.dateTime != null) {
        bookedDates.add(event.start!.dateTime!.toLocal());
      }
    }

    return bookedDates;
  }
}

class CalendarCell extends StatefulWidget {
  final int month;
  final int year;
  final Function(int) onDateSelected;
  final Set<DateTime> bookedDates;

  const CalendarCell({
    super.key,
    required this.month,
    required this.year,
    required this.onDateSelected,
    required this.bookedDates,
  });

  @override
  State<CalendarCell> createState() => _CalendarCellState();
}

class _CalendarCellState extends State<CalendarCell> {
  final Set<int> _selectedDays = {};

  Widget _month() => Text(
        getMonthName(widget.month, GrammaticalCase.nominative),
        style: const TextStyle(fontWeight: FontWeight.bold),
      );

  Widget _dayWeek() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
            .map((day) => Text(day,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))
            .toList(),
      );

  bool _isDateBooked(int day) {
    return widget.bookedDates.any((date) =>
        date.year == widget.year &&
        date.month == widget.month &&
        date.day == day);
  }

  Widget _buildDayNumber(int dayNumber) {
    final isSelected = _selectedDays.contains(dayNumber);
    final isBooked = _isDateBooked(dayNumber);

    return GestureDetector(
      onTap: isBooked
          ? null
          : () {
              setState(() => (isSelected)
                  ? _selectedDays.remove(dayNumber)
                  : _selectedDays.add(dayNumber));
              widget.onDateSelected(dayNumber);
            },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.green : Colors.transparent,
                  width: 1,
                ),
              ),
            ),
          ),
          Text(
            dayNumber.toString(),
            style: TextStyle(
              fontSize: 8,
              color: isBooked ? Colors.red : Colors.black,
            ),
          ),
          if (isBooked)
            const SizedBox.square(
              dimension: 12,
              child: CustomPaint(painter: CrossPainter()),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(widget.year, widget.month + 1, 0).day;
    final firstDayOfMonth = DateTime(widget.year, widget.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;

    return Container(
      padding: const EdgeInsets.all(2),
      child: Column(
        spacing: 4,
        mainAxisSize: MainAxisSize.min,
        children: [
          _month(),
          _dayWeek(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var week = 0; week < 6; week++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (dayIndex) {
                    final dayNumber = week * 7 + dayIndex - firstWeekday + 2;
                    return (dayNumber < 1 || dayNumber > daysInMonth)
                        ? const SizedBox.square(dimension: 16)
                        : _buildDayNumber(dayNumber);
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class CrossPainter extends CustomPainter {
  const CrossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Рисуем крестик по диагоналям контейнера
    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.0)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxWidth * 85.6 / 53.98,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: const Scaffold(
                      body: MediaQuery(
                        data: MediaQueryData(
                          textScaler: TextScaler.linear(1.0),
                        ),
                        child: BookingContainer(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BookingContainer extends StatefulWidget {
  const BookingContainer({super.key});

  @override
  State<BookingContainer> createState() => _BookingContainerState();
}

class _BookingContainerState extends State<BookingContainer> {
  final Set<int> _selectedDays = {};
  Set<DateTime> _bookedDates = {};
  int _selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _loadBookedDates();
  }

  Future<void> _loadBookedDates() async {
    // Тестовые забронированные даты
    final now = DateTime.now();
    final testBookedDates = {
      for (var i = 0; i < 64; i++)
        DateTime(now.year, Random().nextInt(12) + 1, Random().nextInt(28) + 1),
    };

    setState(() {
      _bookedDates = testBookedDates;
    });

    // Раскомментируйте для реальной интеграции с Google Calendar
    // try {
    //   final bookedDates = await CalendarService.getBookedDates();
    //   setState(() {
    //     _bookedDates = bookedDates;
    //   });
    // } catch (e) {
    //   print('Error loading booked dates: $e');
    // }
  }

  void _onDateSelected(int day, int month) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
        _selectedMonth = month;
      }
    });
  }

  String _formatDate(int day, int month) =>
      '$day ${getMonthName(month, GrammaticalCase.genitive)}';

  String _getGreeting() => switch (DateTime.now().hour) {
        >= 5 && < 12 => 'Доброе утро!',
        >= 12 && < 17 => 'Добрый день!',
        >= 17 && < 23 => 'Добрый вечер!',
        _ => 'Доброй ночи!'
      };

  String _getBookingMessage() {
    if (_selectedDays.isEmpty) return '';

    final sortedDays = _selectedDays.toList()..sort();

    // Group consecutive days into intervals
    final intervals = <List<int>>[];
    var currentInterval = <int>[sortedDays.first];

    for (var i = 1; i < sortedDays.length; i++) {
      if (sortedDays[i] == sortedDays[i - 1] + 1) {
        currentInterval.add(sortedDays[i]);
      } else {
        intervals.add(List.from(currentInterval));
        currentInterval = [sortedDays[i]];
      }
    }
    intervals.add(currentInterval);

    // Format intervals
    final formattedIntervals = intervals
        .map((interval) => interval.length == 1
            ? _formatDate(interval.first, _selectedMonth)
            : 'с ${_formatDate(interval.first, _selectedMonth)} '
                'по ${_formatDate(interval.last, _selectedMonth)}')
        .toList();

    // Join intervals with proper conjunctions
    if (formattedIntervals.length == 1) {
      final interval = formattedIntervals.first;
      final hasInterval = interval.startsWith('с');
      return '${_getGreeting()}\nХочу забронировать номер ${hasInterval ? 'на даты ' : 'на '}$interval';
    }

    final lastInterval = formattedIntervals.removeLast();
    return '${_getGreeting()}\nХочу забронировать номер на даты ${formattedIntervals.join(", ")} и $lastInterval';
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedDates = _selectedDays.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFFE3F2FD),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!hasSelectedDates)
                    const Text('Выберите даты в календаре'),
                  if (hasSelectedDates)
                    ElevatedButton(
                      onPressed: () {
                        final message = _getBookingMessage();
                        final url = 'https://t.me/MyZhiraf?text=$message';
                        launchUrl(Uri.parse(url));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Забронировать'),
                    ),
                ],
              ),
            ),
          ),
        ),
        TableContainer(
          onDateSelected: _onDateSelected,
          bookedDates: _bookedDates,
        ),
      ],
    );
  }
}

class TableContainer extends StatelessWidget {
  final Function(int, int) onDateSelected;
  final Set<DateTime> bookedDates;

  const TableContainer({
    super.key,
    required this.onDateSelected,
    required this.bookedDates,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8F5E9),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (rowIndex) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(3, (colIndex) {
                      final monthIndex = rowIndex * 3 + colIndex;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: CalendarCell(
                            month: monthIndex + 1,
                            year: DateTime.now().year,
                            onDateSelected: (day) =>
                                onDateSelected(day, monthIndex + 1),
                            bookedDates: bookedDates,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (rowIndex < 3) const SizedBox(height: 8),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}

void main() {
  runApp(const MainApp());
}
