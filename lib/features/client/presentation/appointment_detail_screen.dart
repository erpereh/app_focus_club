import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_badge.dart';
import '../../../theme/app_theme.dart';
import '../data/mock_client_data.dart';

class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({required this.appointment, super.key});

  final Appointment appointment;

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
                          appointment.serviceType,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      FocusStatusBadge.appointment(appointment.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusDescription(appointment.status),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _DetailGrid(appointment: appointment),
            if (appointment.status == AppointmentStatus.approved &&
                appointment.assignedTrainer != null) ...[
              const SizedBox(height: 18),
              FocusGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FocusKicker('Cita confirmada'),
                    const SizedBox(height: 14),
                    _DetailLine(
                      label: 'Fecha',
                      value:
                          appointment.approvedDateLabel ??
                          appointment.dateLabel,
                    ),
                    _DetailLine(
                      label: 'Hora',
                      value:
                          appointment.approvedTimeLabel ??
                          appointment.timeLabel,
                    ),
                    _DetailLine(
                      label: 'Entrenador',
                      value: appointment.assignedTrainer!,
                    ),
                    if (appointment.sessionType != null)
                      _DetailLine(
                        label: 'Tipo',
                        value: appointment.sessionType!,
                      ),
                  ],
                ),
              ),
            ],
            if (appointment.reason != null) ...[
              const SizedBox(height: 18),
              FocusGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FocusKicker('Tu comentario'),
                    const SizedBox(height: 12),
                    Text(
                      appointment.reason!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
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
                  _DetailLine(label: 'ID', value: appointment.id),
                  _DetailLine(
                    label: 'Fecha de solicitud',
                    value: appointment.createdAtLabel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusDescription(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.pending =>
        'Solicitud enviada. El equipo de Focus Club confirmara la franja.',
      AppointmentStatus.approved =>
        'Cita aprobada. Revisa los datos confirmados antes de acudir.',
      AppointmentStatus.rejected =>
        'Solicitud rechazada. La informacion queda disponible en tu historial.',
    };
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return FocusGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FocusKicker('Franja propuesta'),
          const SizedBox(height: 14),
          _DetailLine(label: 'Servicio', value: appointment.serviceType),
          _DetailLine(
            label: 'Duracion',
            value: '${appointment.durationMinutes} min',
          ),
          _DetailLine(label: 'Fecha', value: appointment.dateLabel),
          _DetailLine(label: 'Hora', value: appointment.timeLabel),
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
