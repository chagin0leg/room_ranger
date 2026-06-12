enum DayStatus { free, booked, selected, unavailable, insufficientNights }

enum DayPosition { single, start, middle, end }

class CalendarDay {
  final DateTime date;
  final DayStatus status;
  final int? price;
  final int? discount;
  final String? currency;
  final DayPosition position;
  final String? groupId;

  CalendarDay({
    required this.date,
    required this.status,
    this.price,
    this.discount,
    this.currency,
    this.position = DayPosition.single,
    this.groupId,
  });

  CalendarDay copyWith({
    DayStatus? status,
    int? price,
    int? discount,
    String? currency,
    DayPosition? position,
    String? groupId,
  }) => CalendarDay(
    date: date,
    status: status ?? this.status,
    price: price ?? this.price,
    discount: discount ?? this.discount,
    currency: currency ?? this.currency,
    position: position ?? this.position,
    groupId: groupId ?? this.groupId,
  );
} 