import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../theme/app_theme.dart';
import '../domain/appointment_calendar.dart';
import '../domain/madrid_date.dart';
import '../domain/portal_models.dart';
import '../widgets/appointment_display.dart';
import '../widgets/client_cards.dart';

/// Month calendar of the signed-in customer's appointments. It only receives
/// the customer's own appointments (the portal stream is filtered by uid and
/// protected by Firestore rules), so no other client's data can appear.
class AppointmentsCalendarView extends StatefulWidget {
  const AppointmentsCalendarView({
    required this.appointments,
    required this.now,
    required this.onOpenDetail,
    required this.trainerNameFor,
    this.bottomPadding = 24,
    super.key,
  });

  final List<Appointment> appointments;
  final DateTime now;
  final ValueChanged<Appointment> onOpenDetail;
  final String? Function(String? trainerId) trainerNameFor;
  final double bottomPadding;

  @override
  State<AppointmentsCalendarView> createState() =>
      _AppointmentsCalendarViewState();
}

class _AppointmentsCalendarViewState extends State<AppointmentsCalendarView> {
  late String _todayKey;
  late CalendarMonth _month;
  late String _selectedDate;

  @override
  void initState() {
    super.initState();
    _todayKey = getMadridDateKey(widget.now);
    _month = CalendarMonth.fromDateKey(_todayKey);
    _selectedDate = _todayKey;
  }

  void _changeMonth(CalendarMonth month) {
    HapticFeedback.selectionClick();
    setState(() {
      _month = month;
      _selectedDate = month == CalendarMonth.fromDateKey(_todayKey)
          ? _todayKey
          : month.dateKey(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final byDate = appointmentsByDateKey(widget.appointments);
    final dayAppointments = byDate[_selectedDate] ?? const <Appointment>[];
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      key: const Key('appointments-calendar'),
      padding: EdgeInsets.fromLTRB(20, 6, 20, widget.bottomPadding),
      children: [
        FocusGlassCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    key: const Key('calendar-previous-month'),
                    tooltip: 'Mes anterior',
                    onPressed: () => _changeMonth(_month.previous),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _month.label,
                      key: const Key('calendar-month-label'),
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const Key('calendar-next-month'),
                    tooltip: 'Mes siguiente',
                    onPressed: () => _changeMonth(_month.next),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final initial in calendarWeekdayInitials)
                    Expanded(
                      child: Center(
                        child: Text(
                          initial,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.9,
                children: [
                  for (final dateKey in _month.gridDateKeys)
                    dateKey == null
                        ? const SizedBox.shrink()
                        : _DayCell(
                            dateKey: dateKey,
                            isToday: dateKey == _todayKey,
                            isSelected: dateKey == _selectedDate,
                            appointments: byDate[dateKey] ?? const [],
                            now: widget.now,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedDate = dateKey);
                            },
                          ),
                ],
              ),
              const SizedBox(height: 8),
              const _Legend(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          TimeSlot(date: _selectedDate, time: '00:00').dateLabel,
          key: const Key('calendar-selected-day'),
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        if (dayAppointments.isEmpty)
          const FocusEmptyState(
            title: 'Sin citas este día',
            description: 'Elige otro día del calendario para ver tus citas.',
            icon: Icons.event_available_rounded,
          )
        else
          ...dayAppointments.map(
            (appointment) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClientAppointmentCard(
                key: Key('calendar-appointment-${appointment.id}'),
                appointment: appointment,
                trainerName: widget.trainerNameFor(
                  appointment.awaitsProposalAnswer
                      ? appointment.proposal?.proposedTrainer ??
                            appointment.assignedTrainer
                      : appointment.assignedTrainer,
                ),
                onTap: () => widget.onOpenDetail(appointment),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dateKey,
    required this.isToday,
    required this.isSelected,
    required this.appointments,
    required this.now,
    required this.onTap,
  });

  final String dateKey;
  final bool isToday;
  final bool isSelected;
  final List<Appointment> appointments;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = int.parse(dateKey.substring(8));
    final dots = appointments
        .map(
          (appointment) => appointmentDisplayStatusColor(appointment, now: now),
        )
        .take(3)
        .toList(growable: false);
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '$day, ${appointments.length} ${appointments.length == 1 ? 'cita' : 'citas'}',
      child: InkWell(
        key: Key('calendar-day-$dateKey'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: AppTheme.motion,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.lime : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isSelected
                ? Border.all(color: AppTheme.textPrimary, width: 1.2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected ? AppTheme.onLime : AppTheme.textPrimary,
                  fontWeight: appointments.isEmpty
                      ? FontWeight.w500
                      : FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in dots)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  static const _items = [
    AppointmentDisplayStatus.approved,
    AppointmentDisplayStatus.pending,
    AppointmentDisplayStatus.proposalPending,
    AppointmentDisplayStatus.awaitingConfirmation,
    AppointmentDisplayStatus.rejected,
    AppointmentDisplayStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final status in _items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: appointmentDisplayStatusTone(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                appointmentDisplayStatusText(status),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
      ],
    );
  }
}
