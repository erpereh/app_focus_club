import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../domain/portal_availability.dart';
import '../domain/portal_models.dart';

const portalServiceLabel = 'Bono Mensual de Entrenamiento';

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
  };
}

Color appointmentStatusColor(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.pending => AppTheme.amber,
    AppointmentStatus.approved => AppTheme.emerald,
    AppointmentStatus.rejected => AppTheme.danger,
  };
}

String appointmentStatusDescription(AppointmentStatus status) {
  return switch (status) {
    AppointmentStatus.pending =>
      'Solicitud enviada. El equipo de Focus Club confirmara la franja.',
    AppointmentStatus.approved =>
      'Cita aprobada. Revisa los datos confirmados antes de acudir.',
    AppointmentStatus.rejected =>
      'Solicitud rechazada. La informacion queda disponible en tu historial.',
  };
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
  String get nameLabel => portalServiceLabel;

  int get usedMinutes => minutosTotales - minutosRestantes;

  double get progress => minutosTotales <= 0
      ? 0
      : (usedMinutes / minutosTotales).clamp(0, 1).toDouble();

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

  String get minutesLabel => '$usedMinutes de $minutosTotales minutos usados';
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
    BonoStatus.activo => AppTheme.emerald,
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

class BookingSlotState {
  const BookingSlotState({
    required this.slot,
    required this.label,
    required this.color,
    required this.isEnabled,
  });

  final TimeSlot slot;
  final String label;
  final Color color;
  final bool isEnabled;
}

List<TimeSlot> buildBookingSlotsForDate({
  required String date,
  required SiteConfig siteConfig,
}) {
  final slots = <TimeSlot>[];
  for (var hour = siteConfig.startHour; hour < siteConfig.endHour; hour += 1) {
    for (var minute = 0; minute < 60; minute += siteConfig.slotInterval) {
      slots.add(
        TimeSlot(
          date: date,
          time: _formatTime(DateTime(2000, 1, 1, hour, minute)),
        ),
      );
    }
  }
  return slots;
}

List<String> buildBookingDates({int days = 21, DateTime? now}) {
  final start = now ?? DateTime.now();
  final startDate = DateTime(start.year, start.month, start.day);
  return List.generate(days, (index) {
    final date = startDate.add(Duration(days: index));
    return _formatWireDate(date);
  });
}

BookingSlotState bookingSlotState({
  required TimeSlot slot,
  required int durationMinutes,
  required Iterable<BlockedSlot> blockedSlots,
  required Iterable<SlotOccupancy> occupancy,
  required Iterable<Appointment> activeAppointments,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final slotDateTime = DateTime.tryParse('${slot.date}T${slot.time}:00');
  if (slotDateTime == null || !slotDateTime.isAfter(current)) {
    return BookingSlotState(
      slot: slot,
      label: 'Pasado',
      color: AppTheme.textSecondary,
      isEnabled: false,
    );
  }
  if (isDurationBlocked(
    start: slot,
    durationMinutes: durationMinutes,
    blockedSlots: blockedSlots,
  )) {
    return BookingSlotState(
      slot: slot,
      label: 'Bloqueado',
      color: AppTheme.danger,
      isEnabled: false,
    );
  }
  if (overlapsActiveAppointment(
    start: slot,
    durationMinutes: durationMinutes,
    appointments: activeAppointments,
  )) {
    return BookingSlotState(
      slot: slot,
      label: 'Tu sesion',
      color: const Color(0xFF6AA7FF),
      isEnabled: false,
    );
  }
  if (isDurationFull(
    start: slot,
    durationMinutes: durationMinutes,
    occupancy: occupancy,
  )) {
    return BookingSlotState(
      slot: slot,
      label: 'Completo',
      color: AppTheme.danger,
      isEnabled: false,
    );
  }

  final maxCount = _maxOccupancyForDuration(
    start: slot,
    durationMinutes: durationMinutes,
    occupancy: occupancy,
  );
  if (maxCount == maxCapacityPerInternalSlot - 1) {
    return BookingSlotState(
      slot: slot,
      label: '1 plaza',
      color: AppTheme.amber,
      isEnabled: true,
    );
  }
  return BookingSlotState(
    slot: slot,
    label: 'Disponible',
    color: AppTheme.emerald,
    isEnabled: true,
  );
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

String _formatWireDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

int _maxOccupancyForDuration({
  required TimeSlot start,
  required int durationMinutes,
  required Iterable<SlotOccupancy> occupancy,
}) {
  final counts = {for (final item in occupancy) item.slot.key: item.count};
  return expandInternalSlots(start, durationMinutes).fold<int>(0, (max, slot) {
    final count = counts[slot.key] ?? 0;
    return count > max ? count : max;
  });
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
