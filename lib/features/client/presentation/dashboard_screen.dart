import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_segmented_control.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../theme/app_theme.dart';
import '../data/mock_client_data.dart';
import '../widgets/client_cards.dart';
import 'appointment_detail_screen.dart';
import 'booking_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.onOpenAppointments,
    required this.onOpenProfile,
    super.key,
  });

  final VoidCallback onOpenAppointments;
  final VoidCallback onOpenProfile;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _historyTabIndex = 0;

  void _openBooking(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BookingScreen()));
  }

  void _openDetail(BuildContext context, Appointment appointment) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailScreen(appointment: appointment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = MockClientData.profile;
    final pass = MockClientData.activePass;
    final appointments = MockClientData.upcomingAppointments;
    final nextAppointment = appointments.firstOrNull;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 42),
        children: [
          _DashboardHeader(
            profile: profile,
            onOpenProfile: widget.onOpenProfile,
          ),
          const SizedBox(height: 28),
          FocusPrimaryButton(
            label: 'Reservar Sesion',
            onPressed: pass.canBook ? () => _openBooking(context) : null,
          ),
          if (!pass.canBook) ...[
            const SizedBox(height: 18),
            const FocusStatusMessage(
              message: 'No tienes minutos disponibles para reservar ahora.',
              type: FocusStatusType.warning,
            ),
          ],
          const SizedBox(height: 30),
          ClientPassCard(pass: pass),
          const SizedBox(height: 22),
          _NextAppointmentCard(
            appointment: nextAppointment,
            onTap: nextAppointment == null
                ? null
                : () => _openDetail(context, nextAppointment),
          ),
          const SizedBox(height: 22),
          Row(
            children: const [
              Expanded(
                child: ClientMetricCard(
                  icon: Icons.fitness_center_rounded,
                  value: '5',
                  label: 'Sesiones realizadas',
                  detail: 'Este bono activo',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ClientMetricCard(
                  icon: Icons.pending_actions_rounded,
                  value: '2',
                  label: 'Citas activas',
                  detail: '1 aprobada - 1 pendiente',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FocusSectionHeader(
            title: 'Mis Citas',
            actionLabel: 'Ver todas',
            onAction: widget.onOpenAppointments,
          ),
          const SizedBox(height: 16),
          if (appointments.isEmpty)
            const FocusEmptyState(
              title: 'Sin citas activas',
              description: 'Tus citas pendientes o aprobadas apareceran aqui.',
              icon: Icons.event_busy_rounded,
            )
          else
            ...appointments.map(
              (appointment) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClientAppointmentCard(
                  appointment: appointment,
                  onTap: () => _openDetail(context, appointment),
                ),
              ),
            ),
          const SizedBox(height: 20),
          FocusSectionHeader(
            title: 'Historial',
            actionLabel: 'Abrir citas',
            onAction: widget.onOpenAppointments,
          ),
          const SizedBox(height: 16),
          _HistoryPreview(
            tabIndex: _historyTabIndex,
            onTabChanged: (index) => setState(() => _historyTabIndex = index),
            onOpenAppointment: (appointment) =>
                _openDetail(context, appointment),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.profile, required this.onOpenProfile});

  final ClientProfile profile;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onOpenProfile,
          child: Tooltip(
            message: 'Abrir perfil',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.emerald.withValues(alpha: 0.34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.emerald.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SizedBox(
                width: 58,
                height: 58,
                child: Center(
                  child: Text(
                    profile.initials,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.emerald,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FocusKicker('Focus Club Vallecas'),
              const SizedBox(height: 5),
              Text(
                profile.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                profile.email,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Salir',
          onPressed: () => Navigator.of(context).pushReplacementNamed('/auth'),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}

class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview({
    required this.tabIndex,
    required this.onTabChanged,
    required this.onOpenAppointment,
  });

  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<Appointment> onOpenAppointment;

  @override
  Widget build(BuildContext context) {
    final appointments = MockClientData.historyAppointments;
    final passes = MockClientData.passHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FocusSegmentedControl(
          options: const [
            FocusSegmentOption(value: 0, label: 'Historial Citas'),
            FocusSegmentOption(value: 1, label: 'Historial Bonos'),
          ],
          selectedValue: tabIndex,
          onChanged: onTabChanged,
        ),
        const SizedBox(height: 18),
        if (tabIndex == 0)
          if (appointments.isEmpty)
            const FocusEmptyState(
              title: 'Sin historial de citas',
              description: 'Las citas anteriores apareceran aqui.',
              icon: Icons.history_rounded,
            )
          else
            ...appointments
                .take(2)
                .map(
                  (appointment) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClientAppointmentCard(
                      appointment: appointment,
                      onTap: () => onOpenAppointment(appointment),
                    ),
                  ),
                )
        else if (passes.isEmpty)
          const FocusEmptyState(
            title: 'Sin historial de bonos',
            description: 'Tus bonos no activos apareceran aqui.',
            icon: Icons.local_activity_outlined,
          )
        else
          ...passes
              .take(2)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PassHistoryCard(item: item),
                ),
              ),
      ],
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({required this.appointment, required this.onTap});

  final Appointment? appointment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (appointment == null) {
      return const FocusEmptyState(
        title: 'Sin citas proximas',
        description:
            'Cuando tengas una cita aprobada o pendiente, la veras aqui.',
        icon: Icons.event_available_rounded,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: FocusGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FocusKicker('Proxima cita'),
            const SizedBox(height: 9),
            Text(
              appointment!.dateLabel,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${appointment!.timeLabel} - ${appointment!.durationMinutes} min',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
