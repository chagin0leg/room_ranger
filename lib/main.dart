import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:room_ranger/utils/date_utils.dart';
import 'package:room_ranger/utils/calendar_service.dart';
import 'package:room_ranger/utils/telegram_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:room_ranger/utils/styles.dart';

// ========================================================================== //

class CalendarCell extends StatefulWidget {
  final int month;
  final int year;
  final Function(DateTime) onDateSelected;
  final Set<DateTime> bookedDates;
  final Set<DateTime> selectedDays;
  final bool isEnabled;

  const CalendarCell({
    super.key,
    required this.month,
    required this.year,
    required this.onDateSelected,
    required this.bookedDates,
    required this.selectedDays,
    this.isEnabled = true,
  });

  @override
  State<CalendarCell> createState() => _CalendarCellState();
}

class _CalendarCellState extends State<CalendarCell> {
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
    return widget.selectedDays
        .contains(DateTime(widget.year, widget.month, day));
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
        final calendarContent = Column(
            children: List.generate(6, (week) {
          return Row(
            children: List.generate(7, (dayIndex) {
              final dayNumber = week * 7 + dayIndex - firstWeekday + 2;
              return _buildDayNumber(dayNumber, daysInMonth);
            }, growable: false),
          );
        }, growable: false));

        // Если календарь отключен, возвращаем только контент без GestureDetector
        if (!widget.isEnabled) {
          return calendarContent;
        }

        // Если календарь включен, оборачиваем в GestureDetector
        return GestureDetector(
          onTapDown: (details) => setState(() => _handleTap(
              details.localPosition, constr, daysInMonth, firstWeekday)),
          onPanStart: (details) => setState(() => _handleDrag(
              details.localPosition, constr, daysInMonth, firstWeekday)),
          onPanUpdate: (details) => setState(() => _handleDrag(
              details.localPosition, constr, daysInMonth, firstWeekday)),
          onPanEnd: (details) => setState(() => _lastHoveredDay = null),
          child: calendarContent,
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
  final Set<DateTime> selectedDays;
  final int selectedYear;
  final bool isEnabled;

  const TableContainer({
    super.key,
    required this.onDateSelected,
    required this.bookedDates,
    required this.selectedDays,
    required this.selectedYear,
    this.isEnabled = true,
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
                          selectedDays: selectedDays,
                          isEnabled: isEnabled,
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
    final maxYear = currentYear + 2;
    final canGoLeft = selectedYear > currentYear;
    final canGoRight = selectedYear < maxYear;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Текст года по центру
        FittedBox(
          fit: BoxFit.contain,
          child: Text(
            selectedYear.toString(),
            style: TextStyle(
              fontSize: getBaseWidth(context) / 100 * 6,
              fontWeight: FontWeight.bold,
              color: colorButtonFg,
            ),
          ),
        ),
        // Кнопки стрелок поверх текста
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed:
                  canGoLeft ? () => onYearChanged(selectedYear - 1) : null,
              icon: Icon(
                Icons.keyboard_arrow_left_rounded,
                color: canGoLeft ? colorButtonFg : Colors.grey,
              ),
            ),
            IconButton(
              onPressed:
                  canGoRight ? () => onYearChanged(selectedYear + 1) : null,
              icon: Icon(
                Icons.keyboard_arrow_right_rounded,
                color: canGoRight ? colorButtonFg : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ========================================================================== //

class BookingButtonContainer extends StatefulWidget {
  final Map<int, Set<DateTime>> selectedDaysByRoom;
  final int selectedMonth;
  final int selectedYear;
  final Function(int) onYearChanged;
  final Function(int) onRoomChanged;
  final int selectedRoom;

  const BookingButtonContainer({
    super.key,
    required this.selectedDaysByRoom,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onYearChanged,
    required this.onRoomChanged,
    required this.selectedRoom,
  });

  @override
  State<BookingButtonContainer> createState() => _BookingButtonContainerState();
}

class _BookingButtonContainerState extends State<BookingButtonContainer> {
  int _pickedRoom = 0;

  @override
  void initState() {
    super.initState();
    _pickedRoom = widget.selectedRoom;
  }

  @override
  void didUpdateWidget(BookingButtonContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRoom != widget.selectedRoom) {
      _pickedRoom = widget.selectedRoom;
    }
  }

  String _getStatusMessage() {
    if (_pickedRoom <= 0) {
      return 'Выберите номер';
    }

    // Проверяем, есть ли выбранные даты в любой комнате
    final hasAnyDates =
        widget.selectedDaysByRoom.values.any((dates) => dates.isNotEmpty);

    if (!hasAnyDates) {
      return 'Выберите даты';
    } else {
      return formatAllBookingDatesText(
        selectedDaysByRoom: widget.selectedDaysByRoom,
        selectedMonth: widget.selectedMonth,
      );
    }
  }

  String _getButtonText() {
    return (widget.selectedDaysByRoom.values.any((dates) => dates.isNotEmpty))
        ? 'Забронировать  '
        : 'Задать вопрос  ';
  }

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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              YearSelector(
                selectedYear: widget.selectedYear,
                onYearChanged: widget.onYearChanged,
              ),
              ElevatedButton(
                onPressed: () async {
                  final message = buildTelegramBookingMessage(
                      selectedDaysByRoom: widget.selectedDaysByRoom,
                      selectedMonth: widget.selectedMonth);
                  await sendTelegramBookingMessage(message);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: colorButtonBg,
                    foregroundColor: colorButtonFg,
                    padding: EdgeInsets.symmetric(
                      horizontal: getButtonTextStyle(context).fontSize! / 2,
                    )),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.telegram_outlined),
                    Text(_getButtonText(), style: getButtonTextStyle(context)),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 6,
                    softWrap: true,
                    // textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: getBookingButtonFontSize(context),
                        color: Colors.grey),
                    '${_getStatusMessage()}\n',
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
      onPressed: () {
        final newRoom = (_pickedRoom != i) ? i : 0;
        setState(() => _pickedRoom = newRoom);
        widget.onRoomChanged(newRoom);
      },
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
  // Храним выбранные даты для каждой комнаты отдельно
  final Map<int, Set<DateTime>> _selectedDaysByRoom = {};
  // Храним загруженные календари для каждой комнаты
  final Map<int, Set<DateTime>> _bookedDatesByRoom = {};
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int _selectedRoom = 0;
  bool _isLoading = true;

  // Геттер для получения выбранных дат текущей комнаты
  Set<DateTime> get _selectedDays => _selectedDaysByRoom[_selectedRoom] ?? {};

  // Геттер для получения занятых дат текущей комнаты
  Set<DateTime> get _bookedDates => _bookedDatesByRoom[_selectedRoom] ?? {};

  @override
  void initState() {
    super.initState();
    _loadAllCalendars();
  }

  Future<void> _loadAllCalendars() async {
    setState(() => _isLoading = true);

    try {
      // Получаем список всех доступных комнат
      final availableRooms = GoogleCalendarService.getAvailableRooms();

      // Загружаем календари для всех комнат параллельно
      final futures = availableRooms.map((roomNumber) async {
        try {
          final bookedDates =
              await GoogleCalendarService.getBookedDates(roomNumber);
          return MapEntry(roomNumber, bookedDates);
        } catch (e) {
          if (kDebugMode) {
            print('Error loading calendar for room $roomNumber: $e');
          }
          // В случае ошибки возвращаем пустой набор
          return MapEntry(roomNumber, <DateTime>{});
        }
      });

      final results = await Future.wait(futures);

      setState(() {
        for (final entry in results) {
          _bookedDatesByRoom[entry.key] = entry.value;
        }
        _isLoading = false;
      });

      if (kDebugMode) {
        print('Loaded calendars for ${results.length} rooms');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading calendars: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      // Получаем или создаем набор дат для текущей комнаты
      final roomDates = _selectedDaysByRoom[_selectedRoom] ?? {};

      if (roomDates.contains(date)) {
        roomDates.remove(date);
      } else {
        roomDates.add(date);
      }

      // Обновляем даты для текущей комнаты
      _selectedDaysByRoom[_selectedRoom] = roomDates;

      // Обновляем выбранный месяц и год
      _selectedMonth = date.month;
      _selectedYear = date.year;
    });
  }

  void _onYearChanged(int newYear) {
    setState(() {
      _selectedYear = newYear;
      // Очищаем выбранные даты при смене года
      // _selectedDays.clear();
    });
  }

  void _onRoomChanged(int room) {
    setState(() {
      _selectedRoom = room;
      // НЕ очищаем выбранные даты при смене комнаты - они сохраняются для каждой комнаты
    });
    // Календари уже загружены при запуске, не нужно перезагружать
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
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: BookingButtonContainer(
                    selectedDaysByRoom: _selectedDaysByRoom,
                    selectedMonth: _selectedMonth,
                    selectedYear: _selectedYear,
                    onYearChanged: _onYearChanged,
                    onRoomChanged: _onRoomChanged,
                    selectedRoom: _selectedRoom,
                  ),
                ),
                TableContainer(
                  onDateSelected: _onDateSelected,
                  bookedDates: _bookedDates,
                  selectedDays: _selectedDays,
                  selectedYear: _selectedYear,
                  isEnabled: _selectedRoom > 0,
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
