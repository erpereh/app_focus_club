import 'package:flutter/material.dart';

import '../../auth/application/auth_scope.dart';
import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_segmented_control.dart';
import '../application/portal_scope.dart';
import '../data/mock_client_data.dart' as mock;
import '../domain/portal_models.dart';
import '../widgets/client_cards.dart';
import 'appointment_detail_screen.dart';
import 'booking_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _tabIndex = 0;

  void _openBooking() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BookingScreen()));
  }

  void _openDetail(Appointment appointment) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailScreen.real(appointment: appointment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthScope.of(context).currentSession;
    final repository = PortalScope.of(context);

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
                  onPressed: _openBooking,
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
            child: session == null
                ? _AppointmentsList(
                    tabIndex: _tabIndex,
                    appointments: const [],
                    error: 'Inicia sesion para ver tus citas.',
                    onOpenDetail: _openDetail,
                  )
                : StreamBuilder<List<Appointment>>(
                    stream: repository.watchAppointmentsByUser(session.uid),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _AppointmentsList(
                          tabIndex: _tabIndex,
                          appointments: const [],
                          error:
                              'No hemos podido cargar tus citas. Intentalo de nuevo en unos minutos.',
                          onOpenDetail: _openDetail,
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final appointments = (snapshot.data ?? const [])
                          .where(_matchesSelectedTab)
                          .toList(growable: false);

                      return _AppointmentsList(
                        tabIndex: _tabIndex,
                        appointments: appointments,
                        onOpenDetail: _openDetail,
                      );
                    },
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
}

class _AppointmentsList extends StatelessWidget {
  const _AppointmentsList({
    required this.tabIndex,
    required this.appointments,
    required this.onOpenDetail,
    this.error,
  });

  final int tabIndex;
  final List<Appointment> appointments;
  final ValueChanged<Appointment> onOpenDetail;
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
              child: ClientAppointmentCard.real(
                appointment: appointment,
                onTap: () => onOpenDetail(appointment),
              ),
            ),
          ),
        if (tabIndex == 1) ...[
          const SizedBox(height: 22),
          const FocusSectionHeader(title: 'Historial de bonos'),
          const SizedBox(height: 16),
          if (mock.MockClientData.passHistory.isEmpty)
            const FocusEmptyState(
              title: 'Sin historial de bonos',
              description: 'Tus bonos no activos apareceran aqui.',
              icon: Icons.local_activity_outlined,
            )
          else
            ...mock.MockClientData.passHistory.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PassHistoryCard(item: item),
              ),
            ),
        ],
      ],
    );
  }
}
