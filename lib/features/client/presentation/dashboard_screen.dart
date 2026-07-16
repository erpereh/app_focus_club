import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_segmented_control.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../shared/widgets/focus_status_badge.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_text_size.dart';
import '../../auth/application/auth_scope.dart';
import '../../../navigation/app_router.dart';
import '../application/client_portal_view_model.dart';
import '../data/push_notification_service.dart';
import '../domain/portal_models.dart';
import '../widgets/appointment_display.dart';
import '../widgets/client_cards.dart';
import 'appointment_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.state,
    required this.viewModel,
    required this.onOpenAppointments,
    required this.onOpenProfile,
    required this.onOpenBooking,
    super.key,
  });

  final ClientPortalState state;
  final ClientPortalViewModel viewModel;
  final VoidCallback onOpenAppointments;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenBooking;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _historyTabIndex = 0;

  void _openDetail(BuildContext context, Appointment appointment) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailScreen(
          appointment: appointment,
          viewModel: widget.viewModel,
          trainerName: _trainerName(appointment.assignedTrainer),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final profile = state.profile;
    final pass = state.activeBono;
    final appointments = state.activeAppointments;
    final dashboardAppointments = state.dashboardAppointments;
    final nextAppointment = dashboardAppointments.firstOrNull;
    final pendingCount = appointments
        .where((item) => item.status == AppointmentStatus.pending)
        .length;
    final approvedCount = appointments
        .where((item) => item.status == AppointmentStatus.approved)
        .length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
        children: [
          _DashboardHeader(
            profile: profile,
            onOpenProfile: widget.onOpenProfile,
            onSignOut: () => _signOut(context),
          ),
          const SizedBox(height: 24),
          FocusPrimaryButton(
            label: 'Reservar Sesion',
            onPressed: pass?.canBook == true ? widget.onOpenBooking : null,
          ),
          if (pass?.canBook != true) ...[
            const SizedBox(height: 18),
            const FocusStatusMessage(
              message: 'No tienes minutos disponibles para reservar ahora.',
              type: FocusStatusType.warning,
            ),
          ],
          const SizedBox(height: 28),
          if (pass == null)
            const FocusEmptyState(
              title: 'Sin bono activo',
              description: 'Cuando tengas un bono activo, aparecera aqui.',
              icon: Icons.local_activity_outlined,
            )
          else
            ClientPassCard(pass: pass),
          const SizedBox(height: 22),
          _NextAppointmentCard(
            appointment: nextAppointment,
            onTap: nextAppointment == null
                ? null
                : () => _openDetail(context, nextAppointment),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final usedMinutesCard = ClientMetricCard(
                icon: Icons.fitness_center_rounded,
                value: '${pass?.usedMinutes ?? 0}',
                label: 'Minutos usados',
                detail: pass == null ? 'Sin bono activo' : 'Este bono activo',
              );
              final appointmentsCard = ClientMetricCard(
                icon: Icons.pending_actions_rounded,
                value: '${appointments.length}',
                label: 'Citas activas',
                detail: '$approvedCount aprobadas\n$pendingCount pendientes',
              );
              final stackCards =
                  AppTextSizing.isLarge(context) && constraints.maxWidth < 340;
              if (stackCards) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    usedMinutesCard,
                    const SizedBox(height: 12),
                    appointmentsCard,
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: usedMinutesCard),
                    const SizedBox(width: 12),
                    Expanded(child: appointmentsCard),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          FocusSectionHeader(
            title: 'Mis Citas',
            actionLabel: 'Ver todas',
            onAction: widget.onOpenAppointments,
          ),
          const SizedBox(height: 16),
          if (dashboardAppointments.isEmpty)
            const FocusEmptyState(
              title: 'Sin citas activas',
              description: 'Tus citas pendientes o aprobadas apareceran aqui.',
              icon: Icons.event_busy_rounded,
            )
          else
            ...dashboardAppointments.map(
              (appointment) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClientAppointmentCard(
                  appointment: appointment,
                  trainerName: _trainerName(appointment.assignedTrainer),
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
            appointments: state.dashboardHistoryAppointments,
            passes: state.inactiveBonos,
            trainerNameFor: _trainerName,
            onTabChanged: (index) => setState(() => _historyTabIndex = index),
            onOpenAppointment: (appointment) =>
                _openDetail(context, appointment),
          ),
        ],
      ),
    );
  }

  String? _trainerName(String? trainerId) {
    if (trainerId == null) return null;
    for (final trainer in widget.state.trainers) {
      if (trainer.id == trainerId) return trainer.name;
    }
    return trainerId;
  }

  Future<void> _signOut(BuildContext context) async {
    final authRepository = AuthScope.of(context);
    final navigator = Navigator.of(context);
    await FirebasePushNotificationService.instance.stop();
    await authRepository.signOut();
    if (!context.mounted) return;
    navigator.pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.profile,
    required this.onOpenProfile,
    required this.onSignOut,
  });

  final UserProfile? profile;
  final VoidCallback onOpenProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onOpenProfile,
          child: Tooltip(
            message: 'Abrir perfil',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surfaceGlass,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.borderStrong.withValues(alpha: 0.20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: SizedBox(
                width: 58,
                height: 58,
                child: _DashboardAvatar(profile: profile),
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
                profile?.name ?? 'Cliente',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                profile?.email ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Salir',
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded, size: 21),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.input.withValues(alpha: 0.50),
            foregroundColor: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DashboardAvatar extends StatelessWidget {
  const _DashboardAvatar({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    if (profile?.hasPhoto != true) {
      return _DashboardAvatarFallback(profile: profile);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.network(
        profile!.photoUrl!,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _DashboardAvatarFallback(profile: profile);
        },
      ),
    );
  }
}

class _DashboardAvatarFallback extends StatelessWidget {
  const _DashboardAvatarFallback({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        profile?.displayInitials ?? '?',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.emerald,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview({
    required this.tabIndex,
    required this.appointments,
    required this.passes,
    required this.trainerNameFor,
    required this.onTabChanged,
    required this.onOpenAppointment,
  });

  final int tabIndex;
  final List<Appointment> appointments;
  final List<Bono> passes;
  final String? Function(String? trainerId) trainerNameFor;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<Appointment> onOpenAppointment;

  @override
  Widget build(BuildContext context) {
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
                      trainerName: trainerNameFor(appointment.assignedTrainer),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FocusKicker('Proxima cita'),
            const SizedBox(height: 10),
            FocusStatusBadge(
              label: appointmentDisplayStatusLabel(appointment!),
              color: appointmentDisplayStatusColor(appointment!),
            ),
            const SizedBox(height: 10),
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
