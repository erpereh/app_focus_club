import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_segmented_control.dart';
import '../application/client_portal_view_model.dart';
import '../domain/portal_models.dart';
import '../widgets/client_cards.dart';
import 'appointment_detail_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({
    required this.state,
    required this.onOpenBooking,
    super.key,
  });

  final ClientPortalState state;
  final VoidCallback onOpenBooking;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _tabIndex = 0;

  void _openDetail(Appointment appointment) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailScreen(
          appointment: appointment,
          trainerName: _trainerName(appointment.assignedTrainer),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Citas',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Consulta tus solicitudes activas e historial.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 26),
                FocusPrimaryButton(
                  label: 'Reservar Sesion',
                  onPressed: widget.onOpenBooking,
                ),
                const SizedBox(height: 24),
                FocusSegmentedControl(
                  options: const [
                    FocusSegmentOption(value: 0, label: 'Proximas'),
                    FocusSegmentOption(value: 1, label: 'Historial'),
                  ],
                  selectedValue: _tabIndex,
                  onChanged: (value) => setState(() => _tabIndex = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.state.error != null
                ? _AppointmentsList(
                    tabIndex: _tabIndex,
                    appointments: const [],
                    error:
                        'No hemos podido cargar tus citas. Intentalo de nuevo en unos minutos.',
                    onOpenDetail: _openDetail,
                    trainerNameFor: _trainerName,
                  )
                : widget.state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _AppointmentsList(
                    tabIndex: _tabIndex,
                    appointments: widget.state.appointments
                        .where(_matchesSelectedTab)
                        .toList(growable: false),
                    inactiveBonos: widget.state.inactiveBonos,
                    onOpenDetail: _openDetail,
                    trainerNameFor: _trainerName,
                  ),
          ),
        ],
      ),
    );
  }

  bool _matchesSelectedTab(Appointment appointment) {
    return switch (_tabIndex) {
      0 =>
        appointment.status == AppointmentStatus.pending ||
            appointment.status == AppointmentStatus.approved,
      _ => appointment.status == AppointmentStatus.rejected,
    };
  }

  String? _trainerName(String? trainerId) {
    if (trainerId == null) return null;
    for (final trainer in widget.state.trainers) {
      if (trainer.id == trainerId) return trainer.name;
    }
    return trainerId;
  }
}

class _AppointmentsList extends StatelessWidget {
  const _AppointmentsList({
    required this.tabIndex,
    required this.appointments,
    required this.onOpenDetail,
    required this.trainerNameFor,
    this.inactiveBonos = const [],
    this.error,
  });

  final int tabIndex;
  final List<Appointment> appointments;
  final List<Bono> inactiveBonos;
  final ValueChanged<Appointment> onOpenDetail;
  final String? Function(String? trainerId) trainerNameFor;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 42),
      children: [
        FocusSectionHeader(
          title: tabIndex == 0 ? 'Proximas' : 'Historial de citas',
        ),
        const SizedBox(height: 16),
        if (error != null)
          FocusEmptyState(
            title: 'No se pudieron cargar las citas',
            description: error!,
            icon: Icons.error_outline_rounded,
          )
        else if (appointments.isEmpty)
          FocusEmptyState(
            title: tabIndex == 0
                ? 'Sin citas activas'
                : 'Sin historial de citas',
            description: tabIndex == 0
                ? 'Tus citas pendientes o aprobadas apareceran aqui.'
                : 'Las citas anteriores apareceran aqui.',
            icon: Icons.event_busy_rounded,
          )
        else
          ...appointments.map(
            (appointment) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClientAppointmentCard(
                appointment: appointment,
                trainerName: trainerNameFor(appointment.assignedTrainer),
                onTap: () => onOpenDetail(appointment),
              ),
            ),
          ),
        if (tabIndex == 1) ...[
          const SizedBox(height: 22),
          const FocusSectionHeader(title: 'Historial de bonos'),
          const SizedBox(height: 16),
          if (inactiveBonos.isEmpty)
            const FocusEmptyState(
              title: 'Sin historial de bonos',
              description: 'Tus bonos no activos apareceran aqui.',
              icon: Icons.local_activity_outlined,
            )
          else
            ...inactiveBonos.map(
              (bono) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PassHistoryCard(item: bono),
              ),
            ),
        ],
      ],
    );
  }
}
