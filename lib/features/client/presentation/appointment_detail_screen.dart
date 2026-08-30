import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_badge.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../theme/app_theme.dart';
import '../application/client_portal_view_model.dart';
import '../data/portal_repository.dart';
import '../domain/portal_models.dart';
import '../domain/recurring_booking.dart';
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
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final state = widget.viewModel.state;
        final appointment = resolveLiveAppointment(
          fallback: widget.appointment,
          appointments: state.appointments,
        );
        final now = widget.viewModel.currentTime;
        final isApproved = appointment.status == AppointmentStatus.approved;
        final assignedTrainer =
            widget.trainerName ??
            state.trainers
                .where((trainer) => trainer.id == appointment.assignedTrainer)
                .map((trainer) => trainer.name)
                .firstOrNull ??
            appointment.assignedTrainer;
        final series = appointment.recurrenceSeriesId == null
            ? null
            : state.recurringSeriesById[appointment.recurrenceSeriesId];
        final showModify = canModifyAppointment(appointment, now);
        final showCancelSeries = canCancelRecurringSeries(appointment, now);
        final showCancelOccurrence = canCancelAppointmentOccurrence(
          appointment,
          now,
        );
        final showActions =
            showModify || showCancelSeries || showCancelOccurrence;

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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final title = Text(
                            appointment.serviceType,
                            style: Theme.of(context).textTheme.titleMedium,
                          );
                          final badge = FocusStatusBadge(
                            label: appointmentDisplayStatusLabel(
                              appointment,
                              now: now,
                            ),
                            color: appointmentDisplayStatusColor(appointment),
                          );
                          if (constraints.maxWidth < 280) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: 10),
                                badge,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: title),
                              const SizedBox(width: 10),
                              badge,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        appointmentDisplayStatusDescription(
                          appointment,
                          now: now,
                        ),
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
                        _DetailLine(
                          label: 'Entrenador',
                          value: assignedTrainer,
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
                if (appointment.isRecurring) ...[
                  const SizedBox(height: 18),
                  FocusGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FocusSectionHeader(title: 'Entrenamiento recurrente'),
                        if (series != null) ...[
                          const SizedBox(height: 14),
                          _DetailLine(
                            label: 'Cada',
                            value: '${series.intervalDays} días',
                          ),
                          _DetailLine(
                            label: 'Sesiones',
                            value: '${series.occurrenceCount} sesiones',
                          ),
                          _DetailLine(
                            label: 'Hasta',
                            value: formatIsoDateEs(series.endDate),
                          ),
                        ],
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
                if (showActions) ...[
                  const SizedBox(height: 22),
                  if (_errorMessage != null) ...[
                    FocusStatusMessage(
                      message: _errorMessage!,
                      type: FocusStatusType.error,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (showModify) ...[
                    FocusPrimaryButton(
                      label: 'Modificar cita',
                      onPressed: _isCancelling
                          ? null
                          : () => _openEdit(appointment),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (showCancelSeries)
                    FocusGhostButton(
                      label: 'Cancelar solicitud recurrente',
                      icon: Icons.cancel_outlined,
                      onPressed: _isCancelling
                          ? null
                          : () => _confirmCancelSeries(appointment),
                    ),
                  if (showCancelOccurrence)
                    FocusGhostButton(
                      label: 'Cancelar cita',
                      icon: Icons.cancel_outlined,
                      onPressed: _isCancelling
                          ? null
                          : () => _confirmCancelOccurrence(appointment),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEdit(Appointment appointment) {
    if (appointment.isRecurring) return Future<void>.value();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingScreen(
          viewModel: widget.viewModel,
          editingAppointment: appointment,
        ),
      ),
    );
  }

  Future<void> _confirmCancelSeries(Appointment appointment) async {
    final seriesId = appointment.recurrenceSeriesId;
    if (seriesId == null) return;
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('¿Cancelar toda la solicitud recurrente?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Se cancelarán todas las sesiones pendientes de esta serie y se devolverán los minutos reservados.',
            ),
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
              child: const Text('Cancelar solicitud'),
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
      await widget.viewModel.cancelRecurringAppointmentSeries(seriesId);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = recurringSeriesMutationErrorMessage(error),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _confirmCancelOccurrence(Appointment appointment) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(
          appointment.isRecurring
              ? '¿Cancelar esta sesión?'
              : '¿Cancelar esta cita?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              appointment.isRecurring
                  ? 'Se devolverán los minutos de esta sesión. El resto de la serie no se cancela.'
                  : 'Se devolverán los minutos a tu bono si corresponde.',
            ),
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
      await widget.viewModel.cancelAppointment(appointment.id);
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelText = Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          );
          final valueText = Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          );
          if (constraints.maxWidth < 280) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 4), valueText],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: labelText),
              Expanded(child: valueText),
            ],
          );
        },
      ),
    );
  }
}
