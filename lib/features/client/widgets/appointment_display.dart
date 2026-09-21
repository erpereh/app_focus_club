import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../domain/madrid_date.dart';
import '../domain/portal_availability.dart';
import '../domain/portal_models.dart';

const sameDayChangeNotAllowedMessage =
    'Las citas no se pueden modificar ni cancelar el mismo día.';

const pendingSeriesHasOccurrenceTodayMessage =
    'Esta serie incluye una cita de hoy y ya no puede cancelarse.';

const portalServiceLabel = 'Bono Mensual de Entrenamiento';

String formatMinutesDuration(int minutes) {
  if (minutes <= 0) return '0min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours == 0) return '${remainingMinutes}min';
  if (remainingMinutes == 0) return '${hours}h';
  return '${hours}h ${remainingMinutes}min';
}

extension PortalAppointmentDisplay on Appointment {
  String get dateLabel => _formatDate(schedulingSlot?.date);

  String get timeLabel =>
      _formatTimeRange(schedulingSlot?.time, durationMinutes);

  String? get approvedDateLabel =>
      approvedSlot == null ? null : _formatDate(approvedSlot!.date);

  String? get approvedTimeLabel => approvedSlot == null
      ? null
      : _formatTimeRange(approvedSlot!.time, durationMinutes);

  String get createdAtLabel {
    final date = _formatIsoDate(createdAt);
    return date == null ? createdAt : 'Solicitada el $date';
  }

  String? get reasonLabel {
    final trimmed = reason.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

String appointmentStatusLabel(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.pending => 'Pendiente',
    AppointmentStatus.approved => 'Aprobada',
    AppointmentStatus.rejected => 'Rechazada',
    AppointmentStatus.cancelled => 'Cancelada',
  };
}

Color appointmentStatusColor(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.pending => AppTheme.amber,
    AppointmentStatus.approved => AppTheme.success,
    AppointmentStatus.rejected => AppTheme.danger,
    AppointmentStatus.cancelled => AppTheme.textSecondary,
  };
}

String appointmentStatusDescription(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.pending =>
      'Solicitud enviada. El equipo de Focus Club confirmará la cita.',
    AppointmentStatus.approved =>
      'Cita aprobada. Revisa los datos confirmados antes de acudir.',
    AppointmentStatus.rejected =>
      'Solicitud rechazada. La informacion queda disponible en tu historial.',
    AppointmentStatus.cancelled => 'Esta cita ha sido cancelada.',
  };
}

String appointmentDisplayStatusLabel(Appointment appointment, {DateTime? now}) {
  final date = appointment.schedulingDateTime;
  final isPast = date != null && !date.isAfter(now ?? DateTime.now());
  if (isPast) {
    if (appointment.status == AppointmentStatus.approved) return 'Realizada';
    if (appointment.status == AppointmentStatus.pending) return 'No realizada';
  }
  return appointmentStatusLabel(appointment.status);
}

String appointmentDisplayStatusDescription(
  Appointment appointment, {
  DateTime? now,
}) {
  final date = appointment.schedulingDateTime;
  final isPast = date != null && !date.isAfter(now ?? DateTime.now());
  if (isPast) {
    if (appointment.status == AppointmentStatus.approved) {
      return 'Esta cita ya se ha realizado.';
    }
    if (appointment.status == AppointmentStatus.pending) {
      return 'La hora de esta solicitud ha pasado sin confirmacion.';
    }
  }
  return appointmentStatusDescription(appointment.status);
}

Color appointmentDisplayStatusColor(Appointment appointment) {
  return appointmentStatusColor(appointment.status);
}

bool canManageAppointmentAt(Appointment appointment, DateTime now) {
  return (appointment.status == AppointmentStatus.pending ||
          appointment.status == AppointmentStatus.approved) &&
      (appointment.schedulingDateTime?.isAfter(now) ?? false);
}

Appointment resolveLiveAppointment({
  required Appointment fallback,
  required Iterable<Appointment> appointments,
}) {
  return appointments.where((item) => item.id == fallback.id).firstOrNull ??
      fallback;
}

bool isAppointmentTodayInMadrid(Appointment appointment, DateTime now) {
  final dateKey = appointment.schedulingSlot?.date;
  if (dateKey == null || dateKey.isEmpty) return false;
  return isDateKeyTodayInMadrid(dateKey, now);
}

bool recurringPendingSeriesHasOccurrenceToday({
  required Appointment appointment,
  required Iterable<Appointment> appointments,
  required DateTime now,
}) {
  final seriesId = appointment.recurrenceSeriesId;
  if (seriesId == null) return false;
  if (appointment.status != AppointmentStatus.pending) return false;

  final byId = <String, Appointment>{appointment.id: appointment};
  for (final item in appointments) {
    byId[item.id] = item;
  }
  return byId.values.any(
    (item) =>
        item.recurrenceSeriesId == seriesId &&
        item.status == AppointmentStatus.pending &&
        isAppointmentTodayInMadrid(item, now),
  );
}

bool canModifyAppointment(Appointment appointment, DateTime now) {
  return canCustomerRescheduleAppointment(appointment, now);
}

bool canCancelRecurringSeries(
  Appointment appointment,
  Iterable<Appointment> appointments,
  DateTime now,
) {
  return canManageAppointmentAt(appointment, now) &&
      appointment.isRecurring &&
      appointment.status == AppointmentStatus.pending &&
      !recurringPendingSeriesHasOccurrenceToday(
        appointment: appointment,
        appointments: appointments,
        now: now,
      );
}

bool canCancelAppointmentOccurrence(Appointment appointment, DateTime now) {
  return canManageAppointmentAt(appointment, now) &&
      !(appointment.isRecurring &&
          appointment.status == AppointmentStatus.pending) &&
      !isAppointmentTodayInMadrid(appointment, now);
}

extension PortalUserDisplay on UserProfile {
  String get displayInitials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  bool get hasPhoto => (photoUrl ?? '').trim().isNotEmpty;
}

extension PortalBonoDisplay on Bono {
  int get displayTotalMinutes {
    if (tamano > 0) return tamano;
    if (minutosTotales > 0) return minutosTotales;
    return 0;
  }

  int get displayRemainingMinutes =>
      minutosRestantes.clamp(0, displayTotalMinutes);

  String get nameLabel {
    final totalLabel = formatMinutesDuration(displayTotalMinutes);
    return displayTotalMinutes > 0
        ? '$portalServiceLabel $totalLabel'
        : portalServiceLabel;
  }

  int get usedMinutes => displayTotalMinutes - displayRemainingMinutes;

  double get progress => displayTotalMinutes <= 0
      ? 0
      : (usedMinutes / displayTotalMinutes).clamp(0, 1).toDouble();

  String get statusLabel => bonoStatusLabel(estado);

  Color get statusColor => bonoStatusColor(estado);

  String get expiresAtLabel {
    final date = _formatIsoDate(fechaExpiracion) ?? fechaExpiracion;
    return date.isEmpty ? 'Sin fecha de caducidad' : 'Valido hasta el $date';
  }

  String get periodLabel {
    final start = _formatIsoDate(fechaAsignacion) ?? fechaAsignacion;
    final end = _formatIsoDate(fechaExpiracion) ?? fechaExpiracion;
    if (start.isEmpty && end.isEmpty) return 'Sin periodo';
    if (start.isEmpty) return 'Hasta $end';
    if (end.isEmpty) return 'Desde $start';
    return '$start - $end';
  }

  String get availableTimeLabel =>
      '${formatMinutesDuration(displayRemainingMinutes)} disponibles';

  String get minutesLabel =>
      '${formatMinutesDuration(usedMinutes)} de ${formatMinutesDuration(displayTotalMinutes)} usados';
}

String bonoStatusLabel(BonoStatus status) {
  return switch (status) {
    BonoStatus.activo => 'Activo',
    BonoStatus.agotado => 'Agotado',
    BonoStatus.expirado => 'Expirado',
    BonoStatus.eliminado => 'Eliminado',
  };
}

Color bonoStatusColor(BonoStatus status) {
  return switch (status) {
    BonoStatus.activo => AppTheme.success,
    BonoStatus.agotado => AppTheme.amber,
    BonoStatus.expirado => AppTheme.textSecondary,
    BonoStatus.eliminado => AppTheme.textSecondary,
  };
}

extension PortalBonoHistoryDisplay on BonoHistorialEntry {
  String get dateLabel => _formatIsoDate(fecha) ?? fecha;

  String get minutesLabel => '$minutos min';
}

extension PortalTimeSlotDisplay on TimeSlot {
  String get dateLabel => _formatDate(date);

  String timeRangeLabel(int durationMinutes) =>
      _formatTimeRange(time, durationMinutes);
}

List<TimeSlot> buildBookingSlotsForDate({
  required String date,
  required SiteConfig siteConfig,
}) {
  final slots = <TimeSlot>[];
  final startMinutes = siteConfig.startHour * 60;
  final endMinutes = siteConfig.endHour * 60;
  final interval = normalizeSlotInterval(siteConfig.slotInterval);
  for (var minutes = startMinutes; minutes < endMinutes; minutes += interval) {
    slots.add(TimeSlot(date: date, time: _formatMinutes(minutes)));
  }
  return slots;
}

List<String> buildBookingDates({int days = 21, DateTime? now}) {
  final start = now ?? DateTime.now();
  final parts = getMadridDateKey(start).split('-').map(int.parse).toList();
  final startDate = DateTime.utc(parts[0], parts[1], parts[2]);
  return List.generate(days, (index) {
    final date = startDate.add(Duration(days: index));
    return _formatWireDate(date);
  });
}

Color bookingSlotColor(BookingSlotAvailability availability) {
  return switch (availability) {
    BookingSlotAvailability.available => AppTheme.emerald,
    BookingSlotAvailability.partial => AppTheme.success,
    BookingSlotAvailability.almostFull => AppTheme.amber,
    BookingSlotAvailability.ownAppointment => const Color(0xFF6AA7FF),
    BookingSlotAvailability.blocked ||
    BookingSlotAvailability.full => AppTheme.danger,
    BookingSlotAvailability.unavailable ||
    BookingSlotAvailability.past => AppTheme.textSecondary,
  };
}

String _formatDate(String? value) {
  if (value == null || value.isEmpty) return 'Sin fecha';
  final parts = value.split('-');
  if (parts.length != 3) return value;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return value;
  if (month < 1 || month > 12 || day < 1 || day > 31) return value;

  final date = DateTime(year, month, day);
  return '${_weekdays[date.weekday - 1]}, ${day.toString().padLeft(2, '0')} ${_months[month - 1]}';
}

String _formatTimeRange(String? value, int durationMinutes) {
  if (value == null || value.isEmpty) return 'Sin hora';
  final parts = value.split(':');
  if (parts.length != 2) return value;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value;

  final start = DateTime(2000, 1, 1, hour, minute);
  final end = start.add(Duration(minutes: durationMinutes));
  return '${_formatTime(start)} - ${_formatTime(end)}';
}

String? _formatIsoDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  final localDate = parsed.toLocal();
  return '${localDate.day.toString().padLeft(2, '0')} ${_months[localDate.month - 1]} ${localDate.year}';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatMinutes(int value) {
  final hour = (value ~/ 60).toString().padLeft(2, '0');
  final minute = (value % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatWireDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

const _weekdays = [
  'Lunes',
  'Martes',
  'Miercoles',
  'Jueves',
  'Viernes',
  'Sabado',
  'Domingo',
];

const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];
