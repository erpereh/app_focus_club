import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_badge.dart';
import '../../../theme/app_theme.dart';
import '../domain/portal_models.dart';
import '../widgets/appointment_display.dart';

class AppointmentDetailScreen extends StatelessWidget {
  AppointmentDetailScreen({
    required Appointment appointment,
    String? trainerName,
    super.key,
  }) : id = appointment.id,
       serviceType = appointment.serviceType,
       durationMinutes = appointment.durationMinutes,
       proposedDateLabel = appointment.dateLabel,
       proposedTimeLabel = appointment.timeLabel,
       statusLabel = appointmentStatusLabel(appointment.status),
       statusColor = appointmentStatusColor(appointment.status),
       statusDescription = appointmentStatusDescription(appointment.status),
       isApproved = appointment.status == AppointmentStatus.approved,
       createdAtLabel = appointment.createdAtLabel,
       reason = appointment.reasonLabel,
       assignedTrainer = trainerName ?? appointment.assignedTrainer,
       sessionType = appointment.sessionType,
       approvedDateLabel = appointment.approvedDateLabel,
       approvedTimeLabel = appointment.approvedTimeLabel;

  final String id;
  final String serviceType;
  final int durationMinutes;
  final String proposedDateLabel;
  final String proposedTimeLabel;
  final String statusLabel;
  final Color statusColor;
  final String statusDescription;
  final bool isApproved;
  final String createdAtLabel;
  final String? reason;
  final String? assignedTrainer;
  final String? sessionType;
  final String? approvedDateLabel;
  final String? approvedTimeLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de la Cita'),
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Volver a mis citas',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            FocusGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          serviceType,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      FocusStatusBadge(label: statusLabel, color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    statusDescription,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _DetailGrid(
              serviceType: serviceType,
              durationMinutes: durationMinutes,
              dateLabel: proposedDateLabel,
              timeLabel: proposedTimeLabel,
            ),
            if (isApproved && assignedTrainer != null) ...[
              const SizedBox(height: 18),
              FocusGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FocusKicker('Cita confirmada'),
                    const SizedBox(height: 14),
                    _DetailLine(
                      label: 'Fecha',
                      value: approvedDateLabel ?? proposedDateLabel,
                    ),
                    _DetailLine(
                      label: 'Hora',
                      value: approvedTimeLabel ?? proposedTimeLabel,
                    ),
                    _DetailLine(label: 'Entrenador', value: assignedTrainer!),
                    if (sessionType != null)
                      _DetailLine(label: 'Tipo', value: sessionType!),
                  ],
                ),
              ),
            ],
            if (reason != null) ...[
              const SizedBox(height: 18),
              FocusGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FocusKicker('Tu comentario'),
                    const SizedBox(height: 12),
                    Text(reason!, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            FocusGlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailLine(label: 'ID', value: id),
                  _DetailLine(
                    label: 'Fecha de solicitud',
                    value: createdAtLabel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({
    required this.serviceType,
    required this.durationMinutes,
    required this.dateLabel,
    required this.timeLabel,
  });

  final String serviceType;
  final int durationMinutes;
  final String dateLabel;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return FocusGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FocusKicker('Franja propuesta'),
          const SizedBox(height: 14),
          _DetailLine(label: 'Servicio', value: serviceType),
          _DetailLine(label: 'Duracion', value: '$durationMinutes min'),
          _DetailLine(label: 'Fecha', value: dateLabel),
          _DetailLine(label: 'Hora', value: timeLabel),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
