import 'package:flutter/material.dart';
import 'package:room_ranger/utils/date_utils.dart';
import 'package:room_ranger/utils/calendar_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:room_ranger/utils/styles.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:room_ranger/utils/price_utils.dart';
import 'package:room_ranger/utils/price_calendar_service.dart';
import 'package:room_ranger/utils/calendar_day.dart';
import 'package:room_ranger/utils/calendar_day_service.dart';
import 'package:room_ranger/utils/telegram_utils.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer';

// ========================================================================== //

class CalendarCell extends StatefulWidget {
  final int month;
  final int year;
  final Function(DateTime) onDateSelected;
  final List<CalendarDay> days;
  final bool isEnabled;

  const CalendarCell({
    super.key,
    required this.month,
    required this.year,
    required this.onDateSelected,
    required this.days,
    this.isEnabled = true,
  });

  @override
  State<CalendarCell> createState() => _CalendarCellState();
}

class _CalendarCellState extends State<CalendarCell> {
  int? _lastHoveredDay;
  bool _isDragging = false;
  Offset? _dragStartPosition;

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

  CalendarDay? _getDay(int day) {
    try {
      return widget.days.firstWhere(
        (d) =>
            d.date.year == widget.year &&
            d.date.month == widget.month &&
            d.date.day == day,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildDayNumber(int dayNumber, int daysInMonth) {
    final day = _getDay(dayNumber);
    if (dayNumber < 1 || dayNumber > daysInMonth || day == null) {
      return Expanded(
          child: SizedBox.square(dimension: getCalendarCellDimension(context)));
    }

    Color? textColor = getDayTextStyle(context).color;
    if (day.status == DayStatus.unavailable) textColor = Colors.grey;

    BoxDecoration decoration;
    switch (day.status) {
      case DayStatus.selected:
        decoration = _getDayDecoration(day.position, colorSelected);
        break;
      case DayStatus.insufficientNights:
        decoration = _getDayDecoration(day.position, colorInsufficientNights);
        break;
      case DayStatus.booked:
        decoration = _getDayDecoration(day.position, colorBooked);
        break;
      default:
        decoration = const BoxDecoration(
          shape: BoxShape.circle,
          color: colorTransparent,
        );
    }

    return Expanded(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: getCalendarCellDimension(context),
            decoration: decoration,
          ),
          Text(
            dayNumber.toString(),
            style: getDayTextStyle(context).copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  BoxDecoration _getDayDecoration(DayPosition position, Color color) {
    final cellSize = getCalendarCellDimension(context);
    final borderRadius = cellSize / 2;

    switch (position) {
      case DayPosition.single:
        return BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
        );
      case DayPosition.start:
        return BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(borderRadius),
            bottomLeft: Radius.circular(borderRadius),
          ),
        );
      case DayPosition.end:
        return BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(borderRadius),
            bottomRight: Radius.circular(borderRadius),
          ),
        );
      case DayPosition.middle:
        return BoxDecoration(
          color: color,
          borderRadius: BorderRadius.zero,
        );
    }
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
          }, growable: false),
        );

        // Если календарь отключен, возвращаем только контент без GestureDetector
        if (!widget.isEnabled) return calendarContent;

        // Если календарь включен, оборачиваем в GestureDetector
        return GestureDetector(
          onTapDown: (details) {
            _dragStartPosition = details.localPosition;
          },
          onPanStart: (details) {
            setState(() {
              _isDragging = true;
              _handleDrag(
                  details.localPosition, constr, daysInMonth, firstWeekday);
            });
          },
          onPanUpdate: (details) => setState(() => _handleDrag(
              details.localPosition, constr, daysInMonth, firstWeekday)),
          onPanEnd: (details) => setState(() {
            _lastHoveredDay = null;
            _isDragging = false;
            _dragStartPosition = null;
          }),
          onTapUp: (details) {
            // Если это был короткий tap (не drag), обрабатываем его
            if (_dragStartPosition != null && !_isDragging) {
              final distance =
                  (_dragStartPosition! - details.localPosition).distance;
              if (distance < 5) {
                // Порог в 5 пикселей
                setState(() => _handleTap(
                    details.localPosition, constr, daysInMonth, firstWeekday));
              }
            }
            _dragStartPosition = null;
          },
          child: calendarContent,
        );
      },
    );
  }

  // Общая логика выбора/снятия выбора дня
  void _toggleDaySelection(int dayNumber, int daysInMonth) {
    if (dayNumber < 1 || dayNumber > daysInMonth) return;
    final day = _getDay(dayNumber);
    if (day == null) return;
    if (day.status == DayStatus.booked || day.status == DayStatus.unavailable)
      return;

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

    final day = _getDay(dayNumber);
    if (day == null) return null;
    if (day.status == DayStatus.booked || day.status == DayStatus.unavailable)
      return null;

    return dayNumber;
  }

  // Обработка клика по сетке дней
  void _handleTap(Offset localPos, BoxConstraints constr, int daysInMonth,
      int firstWeekday) {
    if (mounted) {
      final day = _getDayFromPos(localPos, constr, daysInMonth, firstWeekday);
      if (day == null) return;
      _toggleDaySelection(day, daysInMonth);
    }
  }

  // Определяет, над каким днём сейчас drag, и выделяет его
  void _handleDrag(Offset localPos, BoxConstraints constr, int daysInMonth,
      int firstWeekday) {
    final day = _getDayFromPos(localPos, constr, daysInMonth, firstWeekday);
    if (day == null) return;
    if (_lastHoveredDay == day) return; // Избегаем повторной обработки
    _lastHoveredDay = day;
    _toggleDaySelection(day, daysInMonth);
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
}

// ========================================================================== //

class TableContainer extends StatelessWidget {
  final Function(DateTime) onDateSelected;
  final List<CalendarDay> days;
  final int selectedYear;
  final bool isEnabled;

  const TableContainer({
    super.key,
    required this.onDateSelected,
    required this.days,
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
                    // Фильтруем дни для месяца
                    final monthDays = days
                        .where((d) =>
                            d.date.month == monthIndex + 1 &&
                            d.date.year == selectedYear)
                        .toList();
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
                          days: monthDays,
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
  final Map<int, List<CalendarDay>> daysByRoom;
  final int selectedMonth;
  final int selectedYear;
  final Function(int) onYearChanged;
  final Function(int) onRoomChanged;
  final int selectedRoom;

  const BookingButtonContainer({
    super.key,
    required this.daysByRoom,
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
  int _pickedRoom = 2;

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
    if (_pickedRoom <= 0) return 'Выберите номер';

    final hasSelected = widget.daysByRoom.values
        .any((days) => days.any((d) => d.status == DayStatus.selected));
    final hasInsufficient = hasInsufficientNights();
    final minNights = CalendarDayService.getMinNights();

    if (!hasSelected && !hasInsufficient) return 'Выберите даты';
    if (hasInsufficient) return 'Мин. $minNights ${getNightWord(minNights)}';
    return formatAllBookingDatesText(
      daysByRoom: widget.daysByRoom,
      selectedMonth: widget.selectedMonth,
    );
  }

  String _getButtonText() {
    final hasSelected = widget.daysByRoom.values
        .any((days) => days.any((d) => d.status == DayStatus.selected));
    final hasInsufficient = hasInsufficientNights();
    final minNights = CalendarDayService.getMinNights();

    // Если есть дни с недостаточным количеством ночей, показываем это
    if (hasInsufficient) return 'Мин. $minNights ${getNightWord(minNights)}  ';
    if (hasSelected) return 'Забронировать  ';
    return 'Задать вопрос  ';
  }

  bool hasInsufficientNights() => widget.daysByRoom.values
      .any((days) => days.any((d) => d.status == DayStatus.insufficientNights));

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        Row(
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
                        children: [roomPicker(2), roomPicker(1)],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: Container()),
          ],
        ),
        Row(
          spacing: getBaseWidth(context) / 100 * 10,
          children: [
            Expanded(child: Container()),
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
                      final hasSelected = widget.daysByRoom.values.any((days) =>
                          days.any((d) => d.status == DayStatus.selected));
                      final hasInsufficient = hasInsufficientNights();

                      // Не позволяем переходить к заказу, если есть дни с недостаточным количеством ночей
                      if (!hasSelected || hasInsufficient) return;

                      final message = buildTelegramBookingMessage(
                        daysByRoom: widget.daysByRoom,
                        selectedMonth: widget.selectedMonth,
                      );
                      await sendTelegramBookingMessage(message);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colorButtonBg,
                        foregroundColor: colorButtonFg,
                        padding: EdgeInsets.symmetric(
                          horizontal: getButtonTextStyle(context).fontSize! / 2,
                        )),
                    child: Row(
                      mainAxisAlignment: hasInsufficientNights()
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.spaceBetween,
                      children: [
                        if (!hasInsufficientNights()) ...[
                          const Icon(Icons.telegram_outlined),
                        ],
                        Text(_getButtonText(),
                            style: getButtonTextStyle(context)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        overflow: TextOverflow.ellipsis,
                        maxLines: 6,
                        softWrap: true,
                        style: TextStyle(
                            fontSize: getBookingButtonFontSize(context),
                            color: Colors.grey),
                        _getStatusMessage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  ElevatedButton roomPicker(int i) {
    // Получаем дни для этой комнаты
    final roomDays = widget.daysByRoom[i] ?? [];
    final selectedDays =
        roomDays.where((d) => d.status == DayStatus.selected).toList();
    final insufficientDays = roomDays
        .where((d) => d.status == DayStatus.insufficientNights)
        .toList();
    final allSelectedDays = [...selectedDays, ...insufficientDays];
    final basePrice = calculateTotalPrice(allSelectedDays);
    final finalPrice = calculateFinalPrice(allSelectedDays);

    return ElevatedButton(
      onPressed: () {
        final newRoom = i;
        setState(() => _pickedRoom = newRoom);
        widget.onRoomChanged(newRoom);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _pickedRoom == i ? colorButtonBg : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        minimumSize: Size.square(getRoomButtonSize(context)),
        padding: const EdgeInsets.all(0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (allSelectedDays.isEmpty || basePrice == 0) ...[
            Text(i.toString(), style: getButtonTextStyle(context)),
          ] else ...[
            Text(
              formatPrice(basePrice),
              style: getPriceTextStyle(context).copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: Colors.redAccent,
                decorationThickness: getBaseWidth(context) / 100 * 0.5,
              ),
            ),
            Text(
              '${formatPrice(finalPrice)}${PriceCalendarService.getDefaultCurrency()}',
              style: getPriceTotalTextStyle(context),
            ),
          ],
        ],
      ),
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
  // Храним коллекции дней для каждой комнаты
  Map<int, List<CalendarDay>> _daysByRoom = {};
  Map<int, Set<DateTime>> _bookedMap = {};
  Map<int, Set<DateTime>> _selectedMap = {};
  final int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int _selectedRoom = 2;
  bool _isLoading = true;

  // Геттер для получения дней текущей комнаты
  List<CalendarDay> get _days => _daysByRoom[_selectedRoom] ?? [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // Получаем список всех доступных комнат
      final availableRooms = CalendarService.getAvailableRooms();
      // Загружаем booked для всех комнат
      final bookedMap = <int, Set<DateTime>>{};
      for (final room in availableRooms) {
        final booked = await CalendarService.getBookedDates(room);
        bookedMap[room] = booked.map((d) => d).toSet();
      }
      // Загружаем цены
      await PriceCalendarService.loadPricesFromCalendar();
      // selected пока пустые
      final selectedMap = <int, Set<DateTime>>{};
      // Диапазон дат
      final from = DateTime(_selectedYear, 1, 1);
      final to = DateTime(_selectedYear + 2, 12, 31);
      // Генерируем коллекции дней
      _bookedMap = bookedMap;
      _selectedMap = selectedMap;
      _daysByRoom = CalendarDayService.generateForAllRooms(
        rooms: availableRooms,
        from: from,
        to: to,
        bookedDates: bookedMap,
        selectedDates: selectedMap,
      );
      _isLoading = false;
    } catch (e) {
      if (kDebugMode) {
        log('[loadData] Error loading calendars: $e');
      }
      setState(() => _isLoading = false);
    }
    setState(() {});
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      final days = _daysByRoom[_selectedRoom];
      if (days == null) return;
      final idx = days.indexWhere((d) => d.date == date);
      if (idx == -1) return;
      final current = days[idx];

      if (current.status == DayStatus.selected ||
          current.status == DayStatus.insufficientNights) {
        // Снимаем выделение только с кликнутого дня
        days[idx] = current.copyWith(status: DayStatus.free);
        // Обновляем статусы оставшегося диапазона
        _updateRangeStatuses(days, idx, isRemoving: true);
      } else if (current.status == DayStatus.free) {
        // Выделяем кликнутый день
        days[idx] = current.copyWith(status: DayStatus.selected);
        // Обновляем статусы всего диапазона
        _updateRangeStatuses(days, idx, isRemoving: false);
      }
    });
  }

  /// Обновляет статусы диапазона выбранных дней
  void _updateRangeStatuses(List<CalendarDay> days, int clickedIndex,
      {required bool isRemoving}) {
    // Ищем диапазон подряд идущих выбранных/insufficientNights дней вокруг кликнутого
    int left = clickedIndex;
    while (left > 0 &&
        (days[left - 1].status == DayStatus.selected ||
            days[left - 1].status == DayStatus.insufficientNights)) {
      left--;
    }
    int right = clickedIndex;
    while (right < days.length - 1 &&
        (days[right + 1].status == DayStatus.selected ||
            days[right + 1].status == DayStatus.insufficientNights)) {
      right++;
    }

    List<int> range;
    if (isRemoving) {
      // При снятии выделения исключаем кликнутый день из диапазона
      range = <int>[];
      for (int i = left; i <= right; i++) {
        if (i != clickedIndex &&
            (days[i].status == DayStatus.selected ||
                days[i].status == DayStatus.insufficientNights)) {
          range.add(i);
        }
      }
    } else {
      // При добавлении включаем все дни в диапазоне
      range = List<int>.generate(right - left + 1, (i) => left + i);
    }

    if (range.isEmpty) return;

    // Определяем новый статус на основе количества ночей
    final minNights = CalendarDayService.getMinNights();
    final nights = range.length - 1; // Количество ночей = количество дней - 1
    final newStatus =
        nights >= minNights ? DayStatus.selected : DayStatus.insufficientNights;

    if (kDebugMode) {
      log('[CALENDAR] Range: ${range.length} days ($nights nights) -> $newStatus');
    }

    // Обновляем статусы
    for (final i in range) {
      if (days[i].status == DayStatus.selected ||
          days[i].status == DayStatus.insufficientNights) {
        days[i] = days[i].copyWith(status: newStatus);
      }
    }

    // Пересчитываем groupId и position для диапазона
    final affectedDays = [for (final i in range) days[i]];
    CalendarDayService.applyGroupPositions(affectedDays, newStatus);
    for (int j = 0; j < range.length; j++) {
      days[range[j]] = affectedDays[j];
    }
  }

  void _onYearChanged(int newYear) {
    setState(() {
      _selectedYear = newYear;
      final availableRooms = _daysByRoom.keys.toList();
      final from = DateTime(_selectedYear, 1, 1);
      final to = DateTime(_selectedYear + 2, 12, 31);
      _daysByRoom = CalendarDayService.generateForAllRooms(
        rooms: availableRooms,
        from: from,
        to: to,
        bookedDates: _bookedMap,
        selectedDates: _selectedMap,
      );
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
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: BookingButtonContainer(
                    daysByRoom: _daysByRoom,
                    selectedMonth: _selectedMonth,
                    selectedYear: _selectedYear,
                    onYearChanged: _onYearChanged,
                    onRoomChanged: (room) =>
                        setState(() => _selectedRoom = room),
                    selectedRoom: _selectedRoom,
                  ),
                ),
                Builder(builder: (context) {
                  if (kDebugMode) {
                    log('[CALENDAR] TableContainer: days count = ${_days.length}');
                  }
                  return TableContainer(
                    onDateSelected: _onDateSelected,
                    days: _days,
                    selectedYear: _selectedYear,
                    isEnabled: _selectedRoom > 0,
                  );
                }),
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
      if (kDebugMode) {
        log('[loadApp] Error loading app version: $e');
      }
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
void main() async {
  await dotenv.load();
  runApp(const MainApp());
}
