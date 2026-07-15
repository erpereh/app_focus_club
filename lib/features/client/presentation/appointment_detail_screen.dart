import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_badge.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_text_size.dart';
import '../application/client_portal_view_model.dart';
import '../data/portal_repository.dart';
import '../domain/portal_models.dart';
import '../widgets/appointment_display.dart';
import 'booking_screen.dart';

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({
    required this.appointment,
    required this.viewModel,
    this.trainerName,
    super.key,
  });

  final Appointment appointment;
  final ClientPortalViewModel viewModel;
  final String? trainerName;

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  bool _isCancelling = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final isApproved = appointment.status == AppointmentStatus.approved;
    final assignedTrainer = widget.trainerName ?? appointment.assignedTrainer;
    final canManage =
        (appointment.status == AppointmentStatus.pending || isApproved) &&
        (appointment.schedulingDateTime?.isAfter(DateTime.now()) ?? false);

    return AppTextSizing.region(
      context,
      child: Scaffold(
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
                        FocusStatusBadge(
                          label: appointmentStatusLabel(appointment.status),
                          color: appointmentStatusColor(appointment.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      appointmentStatusDescription(appointment.status),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _DetailGrid(
                serviceType: appointment.serviceType,
                durationMinutes: appointment.durationMinutes,
                dateLabel: appointment.dateLabel,
                timeLabel: appointment.timeLabel,
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
                      _DetailLine(label: 'Entrenador', value: assignedTrainer),
                      if (appointment.sessionType != null)
                        _DetailLine(
                          label: 'Tipo',
                          value: appointment.sessionType!,
                        ),
                    ],
                  ),
                ),
              ],
              if (appointment.reasonLabel != null) ...[
                const SizedBox(height: 18),
                FocusGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FocusKicker('Tu comentario'),
                      const SizedBox(height: 12),
                      Text(
                        appointment.reasonLabel!,
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
              if (canManage) ...[
                const SizedBox(height: 22),
                if (_errorMessage != null) ...[
                  FocusStatusMessage(
                    message: _errorMessage!,
                    type: FocusStatusType.error,
                  ),
                  const SizedBox(height: 14),
                ],
                FocusPrimaryButton(
                  label: 'Modificar cita',
                  onPressed: _isCancelling ? null : _openEdit,
                ),
                const SizedBox(height: 12),
                FocusGhostButton(
                  label: 'Cancelar cita',
                  icon: Icons.cancel_outlined,
                  onPressed: _isCancelling ? null : _confirmCancel,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEdit() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingScreen(
          viewModel: widget.viewModel,
          editingAppointment: widget.appointment,
        ),
      ),
    );
  }

  Future<void> _confirmCancel() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar esta cita?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Se devolverán los minutos a tu bono si corresponde.'),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Volver'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: AppTheme.background,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Cancelar cita'),
            ),
          ],
        ),
      ),
    );
    if (shouldCancel != true || !mounted) return;

    setState(() {
      _isCancelling = true;
      _errorMessage = null;
    });
    try {
      await widget.viewModel.cancelAppointment(widget.appointment.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = appointmentMutationErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
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
