import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_segmented_control.dart';
import '../data/mock_client_data.dart';
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
        builder: (_) => AppointmentDetailScreen(appointment: appointment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointments = _tabIndex == 0
        ? MockClientData.upcomingAppointments
        : MockClientData.historyAppointments;

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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 42),
              children: [
                FocusSectionHeader(
                  title: _tabIndex == 0 ? 'Proximas' : 'Historial de citas',
                ),
                const SizedBox(height: 16),
                if (appointments.isEmpty)
                  FocusEmptyState(
                    title: _tabIndex == 0
                        ? 'Sin citas activas'
                        : 'Sin historial de citas',
                    description: _tabIndex == 0
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
                        onTap: () => _openDetail(appointment),
                      ),
                    ),
                  ),
                if (_tabIndex == 1) ...[
                  const SizedBox(height: 22),
                  const FocusSectionHeader(title: 'Historial de bonos'),
                  const SizedBox(height: 16),
                  if (MockClientData.passHistory.isEmpty)
                    const FocusEmptyState(
                      title: 'Sin historial de bonos',
                      description: 'Tus bonos no activos apareceran aqui.',
                      icon: Icons.local_activity_outlined,
                    )
                  else
                    ...MockClientData.passHistory.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PassHistoryCard(item: item),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
