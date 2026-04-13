import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_badge.dart';
import '../../../theme/app_theme.dart';
import '../data/mock_client_data.dart';

class ClientAppointmentCard extends StatelessWidget {
  const ClientAppointmentCard({
    required this.appointment,
    required this.onTap,
    super.key,
  });

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
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
                        appointment.serviceType,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                FocusStatusBadge.appointment(appointment.status),
              ],
            ),
            const SizedBox(height: 14),
            _InfoLine(
              icon: Icons.schedule_rounded,
              text:
                  '${appointment.dateLabel} - ${appointment.timeLabel} - ${appointment.durationMinutes} min',
            ),
            if (appointment.assignedTrainer != null) ...[
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.person_outline_rounded,
                text: appointment.assignedTrainer!,
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
    return FocusGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.emerald, size: 22),
          const SizedBox(height: 12),
          const FocusKicker('Resumen'),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(detail, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class ClientPassCard extends StatelessWidget {
  const ClientPassCard({required this.pass, super.key});

  final ClientPass pass;

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
              const FocusStatusBadge(label: 'Activo', color: AppTheme.emerald),
            ],
          ),
          const SizedBox(height: 16),
          Text(pass.name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '${pass.remainingMinutes} min disponibles',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pass.progress,
              minHeight: 9,
              backgroundColor: AppTheme.input,
              color: AppTheme.emerald,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${pass.usedMinutes} de ${pass.totalMinutes} minutos usados - ${pass.expiresAtLabel}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class PassHistoryCard extends StatelessWidget {
  const PassHistoryCard({required this.item, super.key});

  final PassHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.statusLabel == 'Agotado'
        ? AppTheme.amber
        : AppTheme.textSecondary;

    return FocusGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              FocusStatusBadge(label: item.statusLabel, color: color),
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
