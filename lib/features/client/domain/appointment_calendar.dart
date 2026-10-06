import 'portal_models.dart';

/// Civil month shown by the customer calendar (no timezone involved: the
/// appointment dates are Europe/Madrid civil `YYYY-MM-DD` keys).
class CalendarMonth {
  const CalendarMonth(this.year, this.month);

  /// Month of a `YYYY-MM-DD` key.
  factory CalendarMonth.fromDateKey(String dateKey) {
    final parts = dateKey.split('-').map(int.parse).toList(growable: false);
    return CalendarMonth(parts[0], parts[1]);
  }

  final int year;
  final int month;

  CalendarMonth get previous =>
      month == 1 ? CalendarMonth(year - 1, 12) : CalendarMonth(year, month - 1);

  CalendarMonth get next =>
      month == 12 ? CalendarMonth(year + 1, 1) : CalendarMonth(year, month + 1);

  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  String dateKey(int day) =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  String get label => '${calendarMonthNames[month - 1]} $year';

  /// Day cells starting on Monday; `null` pads the first week.
  List<String?> get gridDateKeys {
    final leading = DateTime.utc(year, month, 1).weekday - 1;
    return [
      for (var i = 0; i < leading; i++) null,
      for (var day = 1; day <= daysInMonth; day++) dateKey(day),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

const calendarMonthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const calendarWeekdayInitials = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// The customer's own appointments grouped by the day they are shown on,
/// each day sorted by time. Appointments without a valid slot are skipped.
Map<String, List<Appointment>> appointmentsByDateKey(
  Iterable<Appointment> appointments,
) {
  final byDate = <String, List<Appointment>>{};
  for (final appointment in appointments) {
    final slot = appointment.schedulingSlot;
    if (slot == null || slot.date.isEmpty) continue;
    byDate.putIfAbsent(slot.date, () => []).add(appointment);
  }
  for (final list in byDate.values) {
    list.sort(
      (a, b) => (a.schedulingSlot?.time ?? '').compareTo(
        b.schedulingSlot?.time ?? '',
      ),
    );
  }
  return byDate;
}
