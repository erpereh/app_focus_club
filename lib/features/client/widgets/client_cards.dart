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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final startTime = timeLabel.split(' - ').first;
                final timeStyle = Theme.of(context).textTheme.titleMedium;
                final timeWidth = _singleLineWidth(
                  startTime,
                  timeStyle,
                  MediaQuery.textScalerOf(context),
                );
                final leftWidth = timeWidth < 64 ? 64.0 : timeWidth;
                return Row(
                  children: [
                    SizedBox(
                      width: leftWidth,
                      child: Column(
                        children: [
                          Text(
                            dateLabel,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            startTime,
                            key: const Key('appointment-start-time'),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            style: timeStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$timeLabel - $durationMinutes min',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              ?assignedTrainer,
                              if (isRecurring) 'Recurrente',
                            ].where((part) => part.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusDescription,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.42,
                      ),
                      child: FocusStatusBadge(
                        label: statusLabel,
                        color: statusColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
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
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 20),
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
    return FocusBlackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: FocusKicker('Mi bono', onDark: true)),
              FocusStatusBadge(
                label: pass.statusLabel,
                color: pass.statusColor,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            pass.availableTimeLabel,
            key: const Key('pass-available-time'),
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(color: AppTheme.onBlack),
          ),
          const SizedBox(height: 8),
          Text(
            pass.nameLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onBlack.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: pass.progress,
              minHeight: 8,
              backgroundColor: AppTheme.blackElevated,
              color: AppTheme.lime,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${pass.minutesLabel} · ${pass.expiresAtLabel}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.onBlack.withValues(alpha: 0.72),
            ),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child: FocusStatusBadge(
                  label: item.statusLabel,
                  color: item.statusColor,
                ),
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

double _singleLineWidth(String text, TextStyle? style, TextScaler textScaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    textScaler: textScaler,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
