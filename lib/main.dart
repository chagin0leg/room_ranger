import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:room_ranger/utils/date_utils.dart';
import 'package:room_ranger/utils/google_calendar_service.dart';
import 'package:room_ranger/utils/telegram_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:room_ranger/utils/styles.dart';

// ========================================================================== //

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
  int? _lastHoveredDay;

  Widget _month() => Text(
        getMonthName(widget.month, GrammaticalCase.nominative),
        style: getMonthTextStyle(context),
      );

  Widget _dayWeek() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
            .map((day) => SizedBox.square(
                dimension: getCalendarCellDimension(context),
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: getWeekdayTextStyle(context),
                )))
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

  Widget _buildDayNumber(int dayNumber, int daysInMonth) {
    final isSelected = _isDateSelected(dayNumber);
    final isBooked = _isDateBooked(dayNumber);
    Color color = colorTransparent;
    if (isBooked) color = colorBooked;
    if (isSelected) color = colorSelected;

    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return Expanded(
          child: SizedBox.square(dimension: getCalendarCellDimension(context)));
    }
    return Expanded(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: getCalendarCellDimension(context),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          Text(
            dayNumber.toString(),
            style: getDayTextStyle(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeks(int daysInMonth, int firstWeekday) {
    return LayoutBuilder(
      builder: (context, constr) {
        return GestureDetector(
          onTapDown: (details) => setState(() => _handleTap(
              details.localPosition, constr, daysInMonth, firstWeekday)),
          onPanStart: (details) => setState(() => _handleDrag(
              details.localPosition, constr, daysInMonth, firstWeekday)),
          onPanUpdate: (details) => setState(() => _handleDrag(
              details.localPosition, constr, daysInMonth, firstWeekday)),
          onPanEnd: (details) => setState(() => _lastHoveredDay = null),
          child: Column(
              children: List.generate(6, (week) {
            return Row(
              children: List.generate(7, (dayIndex) {
                final dayNumber = week * 7 + dayIndex - firstWeekday + 2;
                return _buildDayNumber(dayNumber, daysInMonth);
              }, growable: false),
            );
          }, growable: false)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(widget.year, widget.month + 1, 0).day;
    final firstDayOfMonth = DateTime(widget.year, widget.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;

    return Container(
      padding: EdgeInsets.all(getCalendarCellMargin(context)),
      child: Column(
        spacing: getCalendarCellSpacing(context),
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _month(),
          _dayWeek(),
          _buildWeeks(daysInMonth, firstWeekday),
        ],
      ),
    );
  }

  // Общая логика выбора/снятия выбора дня
  void _toggleDaySelection(int dayNumber, int daysInMonth) {
    if (dayNumber < 1 || dayNumber > daysInMonth) return;
    if (_isDateBooked(dayNumber)) return;
    final date = DateTime(widget.year, widget.month, dayNumber);
    final isSelected = _selectedDays.contains(date);
    setState(() {
      if (isSelected) {
        _selectedDays.remove(date);
      } else {
        _selectedDays.add(date);
      }
    });
    widget.onDateSelected(date);
  }

  // Получение номера дня по позиции. Возвращает null, если вне диапазона.
  int? _getDayFromPos(Offset localPos, BoxConstraints constr, int daysInMonth,
      int firstWeekday) {
    final cellHeight = getCalendarCellDimension(context);
    final cellWidth = constr.maxWidth / 7;
    final row = (localPos.dy / cellHeight).floor();
    final col = (localPos.dx / cellWidth).floor();
    final dayNumber = row * 7 + col - firstWeekday + 2;
    if (row < 0 || row > 5 || col < 0 || col > 6) return null;
    if (dayNumber < 1 || dayNumber > daysInMonth) return null;
    return dayNumber;
  }

  // Обработка клика по сетке дней
  void _handleTap(Offset localPos, BoxConstraints constr, int daysInMonth,
      int firstWeekday) {
    final day = _getDayFromPos(localPos, constr, daysInMonth, firstWeekday);
    if (day == null) return;
    _toggleDaySelection(day, daysInMonth);
  }

  // Определяет, над каким днём сейчас drag, и выделяет его
  void _handleDrag(Offset localPos, BoxConstraints constr, int daysInMonth,
      int firstWeekday) {
    final day = _getDayFromPos(localPos, constr, daysInMonth, firstWeekday);
    if (day == null) return;
    if (_lastHoveredDay == day) return;
    _lastHoveredDay = day;
    _toggleDaySelection(day, daysInMonth);
  }
}

// ========================================================================== //

class TableContainer extends StatelessWidget {
  final Function(DateTime) onDateSelected;
  final Set<DateTime> bookedDates;
  final int selectedYear;
  const TableContainer({
    super.key,
    required this.onDateSelected,
    required this.bookedDates,
    required this.selectedYear,
  });
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
                        margin: EdgeInsets.all(getCalendarCellMargin(context)),
                        decoration: BoxDecoration(
                          color: colorTableCell,
                          borderRadius: BorderRadius.circular(
                              getCalendarCellBorderRadius(context)),
                        ),
                        child: CalendarCell(
                          month: monthIndex + 1,
                          year: selectedYear,
                          onDateSelected: (date) => onDateSelected(date),
                          bookedDates: bookedDates,
                        ),
                      ),
                    );
                  }),
                ),
                if (rowIndex < 3)
                  SizedBox(height: getCalendarRowSpacing(context)),
              ],
            );
          }),
        );
      },
    );
  }
}

// ========================================================================== //

class YearSelector extends StatelessWidget {
  final int selectedYear;
  final Function(int) onYearChanged;

  const YearSelector({
    super.key,
    required this.selectedYear,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final maxYear = currentYear + 5;
    final canGoLeft = selectedYear > currentYear;
    final canGoRight = selectedYear < maxYear;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: canGoLeft ? () => onYearChanged(selectedYear - 1) : null,
          icon: Icon(
            Icons.arrow_back_ios,
            color: canGoLeft ? colorButtonFg : Colors.grey,
            size: getBaseWidth(context) / 100 * 4,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: getBaseWidth(context) / 100 * 3,
            vertical: getBaseWidth(context) / 100 * 1.5,
          ),
          decoration: BoxDecoration(
            color: colorButtonBg,
            borderRadius:
                BorderRadius.circular(getBaseWidth(context) / 100 * 2),
          ),
          child: Text(
            selectedYear.toString(),
            style: TextStyle(
              fontSize: getBaseWidth(context) / 100 * 3.5,
              fontWeight: FontWeight.bold,
              color: colorButtonFg,
            ),
          ),
        ),
        IconButton(
          onPressed: canGoRight ? () => onYearChanged(selectedYear + 1) : null,
          icon: Icon(
            Icons.arrow_forward_ios,
            color: canGoRight ? colorButtonFg : Colors.grey,
            size: getBaseWidth(context) / 100 * 4,
          ),
        ),
      ],
    );
  }
}

// ========================================================================== //

class BookingButtonContainer extends StatefulWidget {
  final Set<DateTime> selectedDays;
  final int selectedMonth;
  final int selectedYear;
  final Function(int) onYearChanged;

  const BookingButtonContainer({
    super.key,
    required this.selectedDays,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onYearChanged,
  });

  @override
  State<BookingButtonContainer> createState() => _BookingButtonContainerState();
}

class _BookingButtonContainerState extends State<BookingButtonContainer> {
  int _pickedRoom = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              Center(child: Image.asset('assets/home.png')),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [roomPicker(4), roomPicker(3)],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [roomPicker(1), roomPicker(2)],
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            spacing: getCalendarCellSpacing(context),
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              YearSelector(
                selectedYear: widget.selectedYear,
                onYearChanged: widget.onYearChanged,
              ),
              SizedBox(height: getCalendarCellSpacing(context)),
              ElevatedButton(
                onPressed: () async {
                  final message = buildTelegramBookingMessage(
                      selectedDays: widget.selectedDays,
                      selectedMonth: widget.selectedMonth);
                  await sendTelegramBookingMessage(message);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: colorButtonBg,
                    foregroundColor: colorButtonFg,
                    padding: const EdgeInsets.all(0)),
                child:
                    Text('Забронировать', style: getButtonTextStyle(context)),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: getBookingButtonFontSize(context),
                        color: Colors.grey),
                    (widget.selectedDays.isEmpty)
                        ? 'Выберите даты'
                        : formatBookingDatesText(
                            selectedDays: widget.selectedDays,
                            selectedMonth: widget.selectedMonth,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ElevatedButton roomPicker(int i) {
    return ElevatedButton(
      onPressed: () => setState(() => _pickedRoom = (_pickedRoom != i) ? i : 0),
      style: ElevatedButton.styleFrom(
        backgroundColor: _pickedRoom == i ? colorButtonBg : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        minimumSize: Size.square(getRoomButtonSize(context)),
        padding: const EdgeInsets.all(0),
      ),
      child: Text(i.toString(), style: getButtonTextStyle(context)),
    );
  }
}

// ========================================================================== //

class BookingContainer extends StatefulWidget {
  const BookingContainer({super.key});
  @override
  State<BookingContainer> createState() => _BookingContainerState();
}

class _BookingContainerState extends State<BookingContainer> {
  final Set<DateTime> _selectedDays = {};
  Set<DateTime> _bookedDates = {};
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadBookedDates();
  }

  Future<void> _loadBookedDates() async {
    try {
      final bookedDates = await GoogleCalendarService.getBookedDates();
      setState(() => _bookedDates = bookedDates);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading booked dates: $e');
      }
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      if (_selectedDays.contains(date)) {
        _selectedDays.remove(date);
      } else {
        _selectedDays.add(date);
        _selectedMonth = date.month;
        _selectedYear = date.year;
      }
    });
  }

  void _onYearChanged(int newYear) {
    setState(() {
      _selectedYear = newYear;
      // Очищаем выбранные даты при смене года
      // _selectedDays.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(getBookingContainerPadding(context)),
      width: getBaseWidth(context),
      height: getBaseHeight(context),
      decoration: BoxDecoration(
        color: colorBookingBg,
        borderRadius:
            BorderRadius.circular(getBookingContainerBorderRadius(context)),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          Expanded(
            child: BookingButtonContainer(
              selectedDays: _selectedDays,
              selectedMonth: _selectedMonth,
              selectedYear: _selectedYear,
              onYearChanged: _onYearChanged,
            ),
          ),
          TableContainer(
            onDateSelected: _onDateSelected,
            bookedDates: _bookedDates,
            selectedYear: _selectedYear,
          ),
        ],
      ),
    );
  }
}

// ========================================================================== //

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: const SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: BookingContainer(),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(
                    left: getVersionPadding(context),
                    top: getVersionPadding(context)),
                child: Text(_appVersion, style: getVersionTextStyle(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================================================== //
void main() {
  runApp(const MainApp());
}
