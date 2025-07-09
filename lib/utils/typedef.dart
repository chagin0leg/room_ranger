class GroupedDay {
  final DateTime date;
  final String groupId;
  GroupedDay(this.date, this.groupId);
}

enum DayPosition {
  single,
  start,
  middle,
  end,
}
