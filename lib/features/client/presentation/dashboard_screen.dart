import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_badge.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../theme/app_theme.dart';
import '../application/client_portal_view_model.dart';
import '../domain/portal_models.dart';
import '../widgets/appointment_display.dart';
import '../widgets/client_cards.dart';
import 'appointment_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final profile = state.profile;
    final pass = state.activeBono;
    final dashboardAppointments = state.dashboardAppointments;
    final nextAppointment = dashboardAppointments.firstOrNull;
    final recent = dashboardAppointments.take(3).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          AppTheme.navContentInset,
        ),
        children: [
          _DashboardHeader(profile: profile, onOpenProfile: onOpenProfile),
          const SizedBox(height: 28),
          if (pass == null)
            const FocusEmptyState(
              title: 'Sin bono activo',
              description: 'Cuando tengas un bono activo, aparecera aqui.',
              icon: Icons.local_activity_outlined,
            )
          else
            ClientPassCard(pass: pass),
          const SizedBox(height: 24),
          FocusPrimaryButton(
            label: 'Reservar Sesion',
            onPressed: pass?.canBook == true ? onOpenBooking : null,
          ),
          if (pass?.canBook != true) ...[
            const SizedBox(height: 14),
            const FocusStatusMessage(
              message: 'No tienes minutos disponibles para reservar ahora.',
              type: FocusStatusType.warning,
            ),
          ],
          const SizedBox(height: 32),
          const FocusKicker('Proxima sesion'),
          const SizedBox(height: 12),
          _NextAppointmentCard(
            appointment: nextAppointment,
            onOpenBooking: onOpenBooking,
            canBook: pass?.canBook == true,
            onTap: nextAppointment == null
                ? null
                : () => _openDetail(context, nextAppointment),
          ),
          const SizedBox(height: 32),
          FocusSectionHeader(
            title: 'Actividad reciente',
            actionLabel: 'Ver todas',
            onAction: onOpenAppointments,
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const FocusEmptyState(
              title: 'Sin citas activas',
              description: 'Tus citas pendientes o aprobadas apareceran aqui.',
              icon: Icons.event_busy_rounded,
            )
          else
            ...recent.map(
              (appointment) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClientAppointmentCard(
                  appointment: appointment,
                  trainerName: _trainerName(appointment.assignedTrainer),
                  onTap: () => _openDetail(context, appointment),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, Appointment appointment) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailScreen(
          appointment: appointment,
          viewModel: viewModel,
          trainerName: _trainerName(appointment.assignedTrainer),
        ),
      ),
    );
  }

  String? _trainerName(String? trainerId) {
    if (trainerId == null) return null;
    for (final trainer in state.trainers) {
      if (trainer.id == trainerId) return trainer.name;
    }
    return trainerId;
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.profile, required this.onOpenProfile});

  final UserProfile? profile;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final hour = TimeOfDay.now().hour;
    final greeting = hour < 12
        ? 'Buenos dias'
        : hour < 19
        ? 'Buenas tardes'
        : 'Buenas noches';

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onOpenProfile,
          child: Tooltip(
            message: 'Abrir perfil',
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.lime, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: _DashboardAvatar(profile: profile),
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
              Text(greeting, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(
                profile?.name ?? 'Cliente',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontSize: 24),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Abrir perfil',
          onPressed: onOpenProfile,
          icon: const Icon(Icons.person_outline_rounded, size: 22),
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

    return ClipOval(
      child: Image.network(
        profile!.photoUrl!,
        width: 52,
        height: 52,
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.black,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          profile?.displayInitials ?? '?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.lime,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.appointment,
    required this.onOpenBooking,
    required this.canBook,
    required this.onTap,
  });

  final Appointment? appointment;
  final VoidCallback onOpenBooking;
  final bool canBook;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (appointment == null) {
      return SizedBox(
        width: double.infinity,
        child: FocusLimeCard(
          onTap: canBook ? onOpenBooking : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu agenda esta libre',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppTheme.onLime),
              ),
              const SizedBox(height: 6),
              Text(
                'Reserva tu proxima sesion cuando quieras.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onLime.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        child: SizedBox(
          width: double.infinity,
          child: FocusBlackCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: FocusKicker('Proxima cita', onDark: true),
                    ),
                    Flexible(
                      fit: FlexFit.loose,
                      child: FocusStatusBadge(
                        label: appointmentDisplayStatusLabel(appointment!),
                        color: appointmentDisplayStatusColor(appointment!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  appointment!.dateLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: AppTheme.onBlack),
                ),
                const SizedBox(height: 6),
                Text(
                  '${appointment!.timeLabel} - ${appointment!.durationMinutes} min',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.onBlack.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
