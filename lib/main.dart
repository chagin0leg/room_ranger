import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:room_ranger/utils/date_utils.dart';
import 'package:room_ranger/utils/google_calendar_service.dart';
import 'package:room_ranger/utils/telegram_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:room_ranger/utils/styles.dart';

class CalendarCell extends StatefulWidget {
  final int month;
  final int year;
  final Function(DateTime) onDateSelected;
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
  final Set<DateTime> _selectedDays = {};

  Widget _month() => Text(
        getMonthName(widget.month, GrammaticalCase.nominative),
        style: monthTextStyle,
      );

  Widget _dayWeek() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
            .map((day) => Text(day, style: weekdayTextStyle))
            .toList(),
      );

  bool _isDateBooked(int day) {
    return widget.bookedDates.any((date) =>
        date.year == widget.year &&
        date.month == widget.month &&
        date.day == day);
  }

  bool _isDateSelected(int day) {
    return _selectedDays.contains(DateTime(widget.year, widget.month, day));
  }

  Widget _buildDayNumber(int dayNumber) {
    final isSelected = _isDateSelected(dayNumber);
    final isBooked = _isDateBooked(dayNumber);
    final color = isBooked
        ? 0xFFed8f75
        : isSelected
            ? 0xFFd2dfb3
            : 0x00000000;

    return GestureDetector(
      onTap: () {
        if (isBooked) return;
        final date = DateTime(widget.year, widget.month, dayNumber);
        setState(() => (isSelected)
            ? _selectedDays.remove(date)
            : _selectedDays.add(date));
        widget.onDateSelected(date);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(color),
            ),
          ),
          Text(
            dayNumber.toString(),
            style: dayTextStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeks(int daysInMonth, int firstWeekday) {
    return Column(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          _month(),
          _dayWeek(),
          _buildWeeks(daysInMonth, firstWeekday),
        ],
      ),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Center(
              child: SizedBox(
                width: baseWidth,
                height: baseHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: const BookingContainer(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BookingContainer extends StatefulWidget {
  const BookingContainer({
    super.key,
  });
  @override
  State<BookingContainer> createState() => _BookingContainerState();
}

class _BookingContainerState extends State<BookingContainer> {
  final Set<DateTime> _selectedDays = {};
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
    String version = '0.0.0', buildNumber = 'dev';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
      if (kDebugMode) buildNumber += '+dev';
    } catch (e) {
      print('Error loading app version: $e');
    }
    setState(() => _appVersion = 'v$version ($buildNumber)');
  }

  Future<void> _loadBookedDates() async {
    try {
      final bookedDates = await GoogleCalendarService.getBookedDates();
      setState(() => _bookedDates = bookedDates);
    } catch (e) {
      print('Error loading booked dates: $e');
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      if (_selectedDays.contains(date)) {
        _selectedDays.remove(date);
      } else {
        _selectedDays.add(date);
        _selectedMonth = date.month;
      }
    });
  }

  String _formatDate(DateTime date) =>
      '${date.day} ${getMonthName(date.month, GrammaticalCase.genitive)}';

  String _getGreeting() => switch (DateTime.now().hour) {
        >= 5 && < 12 => 'Доброе утро!',
        >= 12 && < 17 => 'Добрый день!',
        >= 17 && < 23 => 'Добрый вечер!',
        _ => 'Доброй ночи!'
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFFE3F2FD),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                    child: const Text('Забронировать', style: buttonTextStyle),
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
            child: Text(_appVersion, style: versionTextStyle),
          ),
      ],
    );
  }
}

class TableContainer extends StatelessWidget {
  final Function(DateTime) onDateSelected;
  final Set<DateTime> bookedDates;
  const TableContainer({
    super.key,
    required this.onDateSelected,
    required this.bookedDates,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFebeed3),
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
                            color: const Color(0xFFfbf4e2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: CalendarCell(
                            month: monthIndex + 1,
                            year: DateTime.now().year,
                            onDateSelected: (date) =>
                                onDateSelected(date),
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
