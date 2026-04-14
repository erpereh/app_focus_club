import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../domain/portal_models.dart';

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
