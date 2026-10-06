import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'notification_models.dart';

class NotificationVisual {
  const NotificationVisual({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}

/// Icon, accent colour and fallback label for each contract `event`.
NotificationVisual notificationVisualFor({
  required String event,
  required String type,
}) {
  return switch (event) {
    'appointment_requested' => const NotificationVisual(
      icon: Icons.schedule_send_rounded,
      color: AppTheme.info,
      label: 'Solicitud de cita',
    ),
    'appointment_confirmed' => const NotificationVisual(
      icon: Icons.check_circle_rounded,
      color: AppTheme.success,
      label: 'Cita confirmada',
    ),
    'appointment_rescheduled' => const NotificationVisual(
      icon: Icons.update_rounded,
      color: AppTheme.info,
      label: 'Cita modificada',
    ),
    'appointment_rejected' => const NotificationVisual(
      icon: Icons.cancel_rounded,
      color: AppTheme.danger,
      label: 'Cita rechazada',
    ),
    'appointment_cancelled' => const NotificationVisual(
      icon: Icons.event_busy_rounded,
      color: AppTheme.danger,
      label: 'Cita cancelada',
    ),
    'appointment_deleted' => const NotificationVisual(
      icon: Icons.event_busy_rounded,
      color: AppTheme.danger,
      label: 'Cita eliminada',
    ),
    'appointment_reminder' => const NotificationVisual(
      icon: Icons.alarm_rounded,
      color: AppTheme.warning,
      label: 'Recordatorio de cita',
    ),
    'appointment_proposed' => const NotificationVisual(
      icon: Icons.event_note_rounded,
      color: AppTheme.info,
      label: 'Nueva hora propuesta',
    ),
    'appointment_proposal_declined' => const NotificationVisual(
      icon: Icons.event_busy_rounded,
      color: AppTheme.textSecondary,
      label: 'Propuesta rechazada',
    ),
    'appointment_series_renewal_pending' => const NotificationVisual(
      icon: Icons.event_repeat_rounded,
      color: AppTheme.info,
      label: 'Citas renovadas por confirmar',
    ),
    'appointment_series_requested' => const NotificationVisual(
      icon: Icons.event_repeat_rounded,
      color: AppTheme.info,
      label: 'Serie solicitada',
    ),
    'appointment_series_confirmed' => const NotificationVisual(
      icon: Icons.event_repeat_rounded,
      color: AppTheme.success,
      label: 'Serie confirmada',
    ),
    'appointment_series_rescheduled' => const NotificationVisual(
      icon: Icons.event_repeat_rounded,
      color: AppTheme.info,
      label: 'Serie modificada',
    ),
    'appointment_series_returned_to_pending' => const NotificationVisual(
      icon: Icons.event_repeat_rounded,
      color: AppTheme.warning,
      label: 'Serie pendiente',
    ),
    'appointment_series_rejected' => const NotificationVisual(
      icon: Icons.event_busy_rounded,
      color: AppTheme.danger,
      label: 'Serie rechazada',
    ),
    'appointment_series_cancelled' => const NotificationVisual(
      icon: Icons.event_busy_rounded,
      color: AppTheme.danger,
      label: 'Serie cancelada',
    ),
    'bono_assigned' || 'bono_renewed' => const NotificationVisual(
      icon: Icons.confirmation_number_rounded,
      color: AppTheme.success,
      label: 'Bono',
    ),
    'bono_validity_changed' => const NotificationVisual(
      icon: Icons.confirmation_number_rounded,
      color: AppTheme.info,
      label: 'Validez del bono',
    ),
    'bono_expiring_7d' || 'bono_expiring_2d' => const NotificationVisual(
      icon: Icons.hourglass_bottom_rounded,
      color: AppTheme.warning,
      label: 'Bono a punto de caducar',
    ),
    'bono_exhausted' => const NotificationVisual(
      icon: Icons.confirmation_number_outlined,
      color: AppTheme.warning,
      label: 'Bono agotado',
    ),
    'bono_expired' => const NotificationVisual(
      icon: Icons.confirmation_number_outlined,
      color: AppTheme.danger,
      label: 'Bono caducado',
    ),
    'support_message' => const NotificationVisual(
      icon: Icons.chat_bubble_rounded,
      color: AppTheme.textPrimary,
      label: 'Mensaje de Focus Club',
    ),
    _ => switch (NotificationCategory.fromType(type)) {
      NotificationCategory.appointmentStatus => const NotificationVisual(
        icon: Icons.event_rounded,
        color: AppTheme.info,
        label: 'Actualización de cita',
      ),
      NotificationCategory.bonoStatus => const NotificationVisual(
        icon: Icons.confirmation_number_rounded,
        color: AppTheme.info,
        label: 'Actualización del bono',
      ),
      NotificationCategory.supportMessage => const NotificationVisual(
        icon: Icons.chat_bubble_rounded,
        color: AppTheme.textPrimary,
        label: 'Mensaje de Focus Club',
      ),
      NotificationCategory.unknown => const NotificationVisual(
        icon: Icons.notifications_rounded,
        color: AppTheme.textSecondary,
        label: 'Aviso',
      ),
    },
  };
}

/// Short relative date in Spanish: "Ahora", "Hace 5 min", "Hace 3 h",
/// "Ayer, 18:30" or "12/09/2026, 18:30" (device local time).
String formatNotificationDate(DateTime? createdAt, DateTime now) {
  if (createdAt == null) return '';
  final local = createdAt.toLocal();
  final current = now.toLocal();
  final difference = current.difference(local);
  String two(int value) => value.toString().padLeft(2, '0');
  final time = '${two(local.hour)}:${two(local.minute)}';
  if (!difference.isNegative && difference.inMinutes < 1) return 'Ahora';
  if (!difference.isNegative && difference.inMinutes < 60) {
    return 'Hace ${difference.inMinutes} min';
  }
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(local.year, local.month, local.day);
  final dayDifference = today.difference(day).inDays;
  if (dayDifference == 0) {
    return difference.isNegative ? time : 'Hace ${difference.inHours} h';
  }
  if (dayDifference == 1) return 'Ayer, $time';
  return '${two(local.day)}/${two(local.month)}/${local.year}, $time';
}
