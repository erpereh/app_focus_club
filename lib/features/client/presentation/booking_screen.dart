import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../shared/widgets/focus_text_field.dart';
import '../../../theme/app_theme.dart';
import '../application/client_portal_view_model.dart';
import '../widgets/appointment_display.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({required this.state, super.key});

  final ClientPortalState state;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _commentController = TextEditingController();
  int _selectedDuration = 45;
  String _selectedDate = buildBookingDates().first;
  BookingSlotState? _selectedSlot;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final activeBono = state.activeBono;
    final siteConfig = state.siteConfig;
    final dates = buildBookingDates();
    final canBook = activeBono?.canBook == true && siteConfig != null;
    final slots = siteConfig == null
        ? const <BookingSlotState>[]
        : buildBookingSlotsForDate(date: _selectedDate, siteConfig: siteConfig)
              .map(
                (slot) => bookingSlotState(
                  slot: slot,
                  durationMinutes: _selectedDuration,
                  blockedSlots: state.blockedSlots,
                  occupancy: state.slotOccupancy,
                  activeAppointments: state.activeAppointments,
                ),
              )
              .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservar Sesion'),
        leading: IconButton(
          tooltip: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            const FocusStatusMessage(
              message:
                  'La reserva real necesita el backend requestAppointment. Ahora mismo no esta disponible en Firebase, asi que no se crearan citas desde la app.',
              type: FocusStatusType.warning,
            ),
            const SizedBox(height: 18),
            _StepCard(
              title: 'Duracion',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeBono == null
                        ? 'No hay bono activo disponible para reservar.'
                        : '${activeBono.minutosRestantes} minutos disponibles en tu bono.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [30, 45, 60].map((duration) {
                      final isEnabled =
                          activeBono != null &&
                          duration <= activeBono.minutosRestantes;
                      return ChoiceChip(
                        label: Text('$duration min'),
                        selected: _selectedDuration == duration,
                        onSelected: isEnabled
                            ? (_) => setState(() {
                                _selectedDuration = duration;
                                _selectedSlot = null;
                              })
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _StepCard(
              title: 'Fecha',
              child: _BookingCalendar(
                selectedDate: _selectedDate,
                dates: dates,
                onSelected: (date) => setState(() {
                  _selectedDate = date;
                  _selectedSlot = null;
                }),
              ),
            ),
            const SizedBox(height: 18),
            _StepCard(
              title: 'Franja horaria',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SlotLegend(),
                  const SizedBox(height: 16),
                  if (!canBook)
                    const FocusStatusMessage(
                      message:
                          'Necesitas un bono activo y la configuracion horaria del centro para seleccionar una franja.',
                      type: FocusStatusType.warning,
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: slots.map((slot) {
                        final isSelected = _selectedSlot?.slot == slot.slot;
                        return _SlotChip(
                          slot: slot,
                          isSelected: isSelected,
                          onTap: slot.isEnabled
                              ? () => setState(() => _selectedSlot = slot)
                              : null,
                        );
                      }).toList(),
                    ),
                  if (_selectedSlot != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Elegida: ${_selectedSlot!.slot.dateLabel} a las ${_selectedSlot!.slot.time}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.emerald,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _StepCard(
              title: 'Comentario opcional',
              child: FocusTextField(
                label: 'Comentario',
                hint: 'Cuentanos si necesitas adaptar la sesion.',
                controller: _commentController,
                icon: Icons.notes_rounded,
                minLines: 3,
                maxLines: 5,
              ),
            ),
            const SizedBox(height: 22),
            const FocusPrimaryButton(
              label: 'Enviar Solicitud',
              onPressed: null,
            ),
            const SizedBox(height: 12),
            FocusGhostButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icons.close_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusSectionHeader(title: title),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  final BookingSlotState slot;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusInput),
      child: Opacity(
        opacity: slot.isEnabled ? 1 : 0.52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.surfaceElevated.withValues(alpha: 0.94)
                : AppTheme.input,
            borderRadius: BorderRadius.circular(AppTheme.radiusInput),
            border: Border.all(
              color: isSelected
                  ? AppTheme.emerald.withValues(alpha: 0.34)
                  : slot.color.withValues(alpha: 0.32),
              width: isSelected ? 1.2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot.slot.time,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  isSelected ? 'Elegida' : slot.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected ? AppTheme.textPrimary : slot.color,
                    fontWeight: FontWeight.w800,
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

class _BookingCalendar extends StatelessWidget {
  const _BookingCalendar({
    required this.selectedDate,
    required this.dates,
    required this.onSelected,
  });

  final String selectedDate;
  final List<String> dates;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedDateTime = DateTime.tryParse(selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              selectedDateTime == null
                  ? 'Calendario'
                  : '${_monthLabel(selectedDateTime.month)} ${selectedDateTime.year}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.48,
          children: dates.map((date) {
            final dateTime = DateTime.tryParse(date);
            final weekday = dateTime == null
                ? ''
                : _weekdayLabel(dateTime.weekday);
            final day = dateTime?.day.toString().padLeft(2, '0') ?? date;
            final month = dateTime == null ? '' : _monthLabel(dateTime.month);
            final isSelected = selectedDate == date;

            return InkWell(
              onTap: () => onSelected(date),
              borderRadius: BorderRadius.circular(AppTheme.radiusInput),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.surfaceElevated.withValues(alpha: 0.94)
                      : AppTheme.input,
                  borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.emerald.withValues(alpha: 0.34)
                        : AppTheme.border,
                    width: isSelected ? 1.2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weekday,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$day $month',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

String _weekdayLabel(int weekday) {
  return const ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'][weekday - 1];
}

String _monthLabel(int month) {
  return const [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ][month - 1];
}

class _SlotLegend extends StatelessWidget {
  const _SlotLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: const [
        _LegendItem(color: AppTheme.emerald, label: 'Disponible'),
        _LegendItem(color: AppTheme.amber, label: 'Casi lleno'),
        _LegendItem(color: AppTheme.danger, label: 'Completo'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
