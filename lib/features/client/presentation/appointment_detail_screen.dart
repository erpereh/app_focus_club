import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_badge.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../theme/app_theme.dart';
import '../application/client_portal_view_model.dart';
import '../data/portal_repository.dart';
import '../domain/madrid_date.dart';
import '../domain/portal_availability.dart';
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
        final showCancelSeries = canCancelRecurringSeries(
          appointment,
          state.appointments,
          now,
        );
        final showCancelOccurrence = canCancelAppointmentOccurrence(
          appointment,
          now,
        );
        final showActions =
            showModify || showCancelSeries || showCancelOccurrence;
        final showSeriesTodayWarning = recurringPendingSeriesHasOccurrenceToday(
          appointment: appointment,
          appointments: state.appointments,
          now: now,
        );
        final showSameDayWarning =
            !showSeriesTodayWarning &&
            (appointment.status == AppointmentStatus.pending ||
                appointment.status == AppointmentStatus.approved) &&
            isAppointmentTodayInMadrid(appointment, now);
        final appointmentSlot = appointment.schedulingSlot;
        final showRescheduleLockWarning =
            (appointment.status == AppointmentStatus.pending ||
                appointment.status == AppointmentStatus.approved) &&
            appointmentSlot != null &&
            isMadridSlotFuture(
              date: appointmentSlot.date,
              time: appointmentSlot.time,
              now: now,
            ) &&
            isInsideCustomerRescheduleLockWindow(
              date: appointmentSlot.date,
              time: appointmentSlot.time,
              now: now,
            );
        final warningMessage = showSeriesTodayWarning
            ? pendingSeriesHasOccurrenceTodayMessage
            : showSameDayWarning
            ? sameDayChangeNotAllowedMessage
            : showRescheduleLockWarning
            ? 'Esta cita ya está dentro del plazo de 24 horas previo al entrenamiento y no puede modificarse.'
            : null;

        return Scaffold(
          backgroundColor: AppTheme.background,
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium,
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
                        const FocusSectionHeader(
                          title: 'Entrenamiento recurrente',
                        ),
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
                            value: formatIsoDateEs(
                              series.futureEndDate ?? series.endDate,
                            ),
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
                if (_errorMessage != null ||
                    warningMessage != null ||
                    showActions) ...[
                  const SizedBox(height: 22),
                  if (_errorMessage != null) ...[
                    FocusStatusMessage(
                      message: _errorMessage!,
                      type: FocusStatusType.error,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (warningMessage != null) ...[
                    FocusStatusMessage(
                      message: warningMessage,
                      type: FocusStatusType.warning,
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

  Future<void> _openEdit(Appointment appointment) async {
    var mode = BookingEditMode.singleAppointment;
    RecurringAppointmentSeries? series;
    if (appointment.isRecurring) {
      final state = widget.viewModel.state;
      series = state.recurringSeriesById[appointment.recurrenceSeriesId];
      final canReplaceSeriesTemporally =
          series != null &&
          canCustomerReplaceRecurringSeries(
            seriesId: series.id,
            appointments: state.appointments,
            now: widget.viewModel.currentTime,
          );
      final replacementBonoId = series?.bonoId;
      final replacementBono = replacementBonoId == null
          ? null
          : state.bonos
                .where((bono) => bono.id == replacementBonoId)
                .firstOrNull;
      final hasReplacementBono =
          replacementBono != null &&
          replacementBono.estado != BonoStatus.eliminado;
      final canReplaceSeries = canReplaceSeriesTemporally && hasReplacementBono;
      final selected = await showModalBottomSheet<BookingEditMode>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) => _RecurringEditScopeSheet(
          canReplaceSeries: canReplaceSeries,
          hasSeries: series != null,
          hasReplacementBono: hasReplacementBono,
        ),
      );
      if (!mounted || selected == null) return;
      mode = selected;
      if (mode == BookingEditMode.recurringSeries && !canReplaceSeries) {
        setState(() {
          _errorMessage = series == null
              ? 'No hemos podido cargar todavía los datos de esta serie.'
              : !hasReplacementBono
              ? 'El bono asociado ya no está disponible.'
              : 'Una de las sesiones de esta serie ya está dentro del plazo de 24 horas previo y no puede reprogramarse toda la serie.';
        });
        return;
      }
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingScreen(
          viewModel: widget.viewModel,
          editMode: mode,
          sourceAppointment: appointment,
          sourceSeries: mode == BookingEditMode.recurringSeries ? series : null,
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
                foregroundColor: AppTheme.white,
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
                foregroundColor: AppTheme.white,
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

class _RecurringEditScopeSheet extends StatelessWidget {
  const _RecurringEditScopeSheet({
    required this.canReplaceSeries,
    required this.hasSeries,
    required this.hasReplacementBono,
  });

  final bool canReplaceSeries;
  final bool hasSeries;
  final bool hasReplacementBono;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              '¿Qué quieres modificar?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 18),
            _ScopeCard(
              icon: Icons.event_outlined,
              title: 'Solo esta sesión',
              subtitle: 'Modifica únicamente este entrenamiento.',
              onTap: () =>
                  Navigator.of(context).pop(BookingEditMode.recurringSingle),
            ),
            const SizedBox(height: 12),
            _ScopeCard(
              icon: Icons.event_repeat_rounded,
              title: 'Toda la serie',
              subtitle: canReplaceSeries
                  ? 'Reprograma las sesiones futuras de esta serie.'
                  : !hasSeries
                  ? 'Los datos de la serie todavía no están disponibles.'
                  : !hasReplacementBono
                  ? 'El bono asociado ya no está disponible.'
                  : 'Una sesión futura ya está dentro del plazo de 24 horas.',
              enabled: canReplaceSeries,
              onTap: () =>
                  Navigator.of(context).pop(BookingEditMode.recurringSeries),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: FocusGlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.lime.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppTheme.success),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                  ),
              ],
            ),
          ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelText = Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          );
          final valueText = Text(
            value,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
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
