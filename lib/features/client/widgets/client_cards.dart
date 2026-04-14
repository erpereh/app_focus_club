import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_badge.dart';
import '../../../theme/app_theme.dart';
import '../domain/portal_models.dart';
import 'appointment_display.dart';

class ClientAppointmentCard extends StatelessWidget {
  ClientAppointmentCard({
    required Appointment appointment,
    required this.onTap,
    String? trainerName,
    super.key,
  }) : serviceType = appointment.serviceType,
       statusLabel = appointmentStatusLabel(appointment.status),
       statusColor = appointmentStatusColor(appointment.status),
       dateLabel = appointment.dateLabel,
       timeLabel = appointment.timeLabel,
       durationMinutes = appointment.durationMinutes,
       assignedTrainer = trainerName ?? appointment.assignedTrainer;

  final String serviceType;
  final String statusLabel;
  final Color statusColor;
  final String dateLabel;
  final String timeLabel;
  final int durationMinutes;
  final String? assignedTrainer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: FocusGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FocusKicker('Cita'),
                      const SizedBox(height: 6),
                      Text(
                        serviceType,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                FocusStatusBadge(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 14),
            _InfoLine(
              icon: Icons.schedule_rounded,
              text: '$dateLabel - $timeLabel - $durationMinutes min',
            ),
            if (assignedTrainer != null) ...[
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.person_outline_rounded,
                text: assignedTrainer!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ClientMetricCard extends StatelessWidget {
  const ClientMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 21),
            const SizedBox(height: 14),
            const FocusKicker('Resumen'),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(detail, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class ClientPassCard extends StatelessWidget {
  const ClientPassCard({required this.pass, super.key});

  final Bono pass;

  @override
  Widget build(BuildContext context) {
    return FocusGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_activity_outlined,
                color: AppTheme.emerald,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mi Bono',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FocusStatusBadge(
                label: pass.statusLabel,
                color: pass.statusColor,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(pass.nameLabel, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '${pass.minutosRestantes} min disponibles',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            child: LinearProgressIndicator(
              value: pass.progress,
              minHeight: 9,
              backgroundColor: AppTheme.input,
              color: AppTheme.emerald,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${pass.usedMinutes} de ${pass.minutosTotales} minutos usados - ${pass.expiresAtLabel}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class PassHistoryCard extends StatelessWidget {
  const PassHistoryCard({required this.item, super.key});

  final Bono item;

  @override
  Widget build(BuildContext context) {
    return FocusGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.nameLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              FocusStatusBadge(
                label: item.statusLabel,
                color: item.statusColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.periodLabel, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            item.minutesLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
