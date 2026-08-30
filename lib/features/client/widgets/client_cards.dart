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
       statusLabel = appointmentDisplayStatusLabel(appointment),
       statusDescription = appointmentDisplayStatusDescription(appointment),
       statusColor = appointmentDisplayStatusColor(appointment),
       dateLabel = appointment.dateLabel,
       timeLabel = appointment.timeLabel,
       durationMinutes = appointment.durationMinutes,
       assignedTrainer = trainerName ?? appointment.assignedTrainer,
       isRecurring = appointment.isRecurring;

  final String serviceType;
  final String statusLabel;
  final String statusDescription;
  final Color statusColor;
  final String dateLabel;
  final String timeLabel;
  final int durationMinutes;
  final String? assignedTrainer;
  final bool isRecurring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: FocusGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FocusKicker('Cita'),
                    const SizedBox(height: 6),
                    Text(
                      serviceType,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                );
                final badge = FocusStatusBadge(
                  label: statusLabel,
                  color: statusColor,
                );
                if (constraints.maxWidth < 280) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [heading, const SizedBox(height: 10), badge],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 10),
                    badge,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              statusDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _InfoLine(
              icon: Icons.schedule_rounded,
              text: '$dateLabel - $timeLabel - $durationMinutes min',
            ),
            if (isRecurring) ...[
              const SizedBox(height: 8),
              const _InfoLine(
                icon: Icons.repeat_rounded,
                text: 'Recurrente',
              ),
            ],
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
        color: AppTheme.surfaceGlass.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: AppTheme.borderStrong.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.input.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Icon(icon, color: AppTheme.textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
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
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.input.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    Icons.local_activity_outlined,
                    color: AppTheme.emerald,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
            pass.availableTimeLabel,
            key: const Key('pass-available-time'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            child: LinearProgressIndicator(
              value: pass.progress,
              minHeight: 8,
              backgroundColor: AppTheme.input.withValues(alpha: 0.86),
              color: AppTheme.emerald,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${pass.minutesLabel} - ${pass.expiresAtLabel}',
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
      padding: const EdgeInsets.all(18),
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
