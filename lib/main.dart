import 'package:flutter/material.dart';
import 'package:room_ranger/utils/date_utils.dart';
import 'package:room_ranger/utils/google_calendar_service.dart';
import 'package:room_ranger/utils/telegram_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadBookedDates();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      const envVersion = String.fromEnvironment('VERSION', defaultValue: '');
      final packageInfo = await PackageInfo.fromPlatform();

      setState(() => _appVersion =
          '${envVersion.isNotEmpty ? 'v$envVersion' : 'v${packageInfo.version}'} (${packageInfo.buildNumber})');
    } catch (e) {
      print('Error loading app version: $e');
      setState(() => _appVersion = 'v0.0.0 (0)');
    }
  }

  Future<void> _loadBookedDates() async {
    try {
      final bookedDates = await GoogleCalendarService.getBookedDates();
      setState(() => _bookedDates = bookedDates);
    } catch (e) {
      print('Error loading booked dates: $e');
    }
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
                      onPressed: () async {
                        final message = buildTelegramBookingMessage(
                          selectedDays: _selectedDays,
                          selectedMonth: _selectedMonth,
                          formatDate: _formatDate,
                          getGreeting: _getGreeting,
                        );
                        await sendTelegramBookingMessage(message);
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
        if (_appVersion.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _appVersion,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
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
