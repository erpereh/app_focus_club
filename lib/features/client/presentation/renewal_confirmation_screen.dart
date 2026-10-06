import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../theme/app_theme.dart';
import '../application/client_portal_view_model.dart';
import '../data/portal_repository.dart';
import '../domain/portal_models.dart';
import '../widgets/client_cards.dart';
import 'appointment_detail_screen.dart';

/// Renewed appointments the admin prepared with the new bono. The customer
/// confirms them all at once or opens each one to confirm or decline it.
class RenewalConfirmationScreen extends StatefulWidget {
  const RenewalConfirmationScreen({required this.viewModel, super.key});

  final ClientPortalViewModel viewModel;

  @override
  State<RenewalConfirmationScreen> createState() =>
      _RenewalConfirmationScreenState();
}

class _RenewalConfirmationScreenState extends State<RenewalConfirmationScreen> {
  bool _isConfirming = false;
  String? _message;
  FocusStatusType _messageType = FocusStatusType.success;
  Map<String, String> _failures = const {};

  Future<void> _confirmAll(List<Appointment> pending) async {
    setState(() {
      _isConfirming = true;
      _message = null;
      _failures = const {};
    });
    final failures = await widget.viewModel.confirmAllRenewedAppointments(
      pending,
    );
    if (!mounted) return;
    final confirmed = pending.length - failures.length;
    setState(() {
      _isConfirming = false;
      _failures = failures.map(
        (id, error) => MapEntry(id, customerConfirmationErrorMessage(error)),
      );
      if (failures.isEmpty) {
        _messageType = FocusStatusType.success;
        _message = confirmed == 1
            ? 'Cita confirmada.'
            : 'Se han confirmado $confirmed citas.';
      } else {
        _messageType = FocusStatusType.warning;
        _message =
            'Se han confirmado $confirmed de ${pending.length} citas. Revisa las que ya no estaban disponibles.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final state = widget.viewModel.state;
        final now = widget.viewModel.currentTime;
        final pending = state.pendingRenewalsAt(now);
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Citas por confirmar'),
            leading: IconButton(
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          body: SafeArea(
            child: ListView(
              key: const Key('renewal-confirmation-list'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                Text(
                  'Hemos preparado estas citas con tu nuevo bono. Quedan reservadas cuando las confirmas.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                if (_message != null) ...[
                  FocusStatusMessage(message: _message!, type: _messageType),
                  const SizedBox(height: 14),
                ],
                if (pending.isEmpty)
                  const FocusEmptyState(
                    title: 'No tienes citas por confirmar',
                    description:
                        'Las citas renovadas pendientes aparecerán aquí.',
                    icon: Icons.event_available_rounded,
                  )
                else ...[
                  FocusPrimaryButton(
                    key: const Key('renewal-confirm-all'),
                    label: pending.length == 1
                        ? 'Confirmar cita'
                        : 'Confirmar todas (${pending.length})',
                    isLoading: _isConfirming,
                    onPressed: _isConfirming
                        ? null
                        : () => _confirmAll(pending),
                  ),
                  const SizedBox(height: 18),
                  for (final appointment in pending) ...[
                    ClientAppointmentCard(
                      appointment: appointment,
                      trainerName: _trainerName(
                        state,
                        appointment.assignedTrainer,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AppointmentDetailScreen(
                            appointment: appointment,
                            viewModel: widget.viewModel,
                            trainerName: _trainerName(
                              state,
                              appointment.assignedTrainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_failures[appointment.id] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: FocusStatusMessage(
                          message: _failures[appointment.id]!,
                          type: FocusStatusType.error,
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String? _trainerName(ClientPortalState state, String? trainerId) {
    if (trainerId == null) return null;
    for (final trainer in state.trainers) {
      if (trainer.id == trainerId) return trainer.name;
    }
    return trainerId;
  }
}

/// Banner shown on the dashboard and the appointments tab.
class PendingRenewalsBanner extends StatelessWidget {
  const PendingRenewalsBanner({
    required this.count,
    required this.onReview,
    super.key,
  });

  final int count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('pending-renewals-banner'),
      color: const Color(0xFF6AA7FF).withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: InkWell(
        onTap: onReview,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.event_repeat_rounded,
                color: AppTheme.textPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  count == 1
                      ? 'Tienes 1 cita renovada por confirmar'
                      : 'Tienes $count citas renovadas por confirmar',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                'Revisar',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
