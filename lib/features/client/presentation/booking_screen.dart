import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../shared/widgets/focus_text_field.dart';
import '../../../theme/app_theme.dart';
import '../application/client_portal_view_model.dart';
import '../data/portal_repository.dart';
import '../widgets/appointment_display.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({required this.viewModel, super.key});

  final ClientPortalViewModel viewModel;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _commentController = TextEditingController();
  int _selectedDuration = 45;
  String _selectedDate = buildBookingDates().first;
  BookingSlotState? _selectedSlot;
  String? _statusMessage;
  FocusStatusType _statusType = FocusStatusType.success;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_handlePortalChange);
  }

  @override
  void didUpdateWidget(BookingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel == widget.viewModel) return;
    oldWidget.viewModel.removeListener(_handlePortalChange);
    widget.viewModel.addListener(_handlePortalChange);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_handlePortalChange);
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.viewModel.state;
    final activeBono = state.activeBono;
    final siteConfig = state.siteConfig;
    final dates = buildBookingDates();
    final canBook =
        activeBono?.canBook == true &&
        siteConfig != null &&
        _selectedDuration <= (activeBono?.minutosRestantes ?? 0);
    final slots = siteConfig == null
        ? const <BookingSlotState>[]
        : buildBookingSlotsForDate(date: _selectedDate, siteConfig: siteConfig)
              .map(
                (slot) => bookingSlotState(
                  slot: slot,
                  durationMinutes: _selectedDuration,
                  siteConfig: siteConfig,
                  blockedSlots: state.blockedSlots,
                  occupancy: state.slotOccupancy,
                  activeAppointments: state.activeAppointments,
                ),
              )
              .toList(growable: false);
    final recalculatedSelectedSlot = _selectedSlot == null
        ? null
        : slots.where((slot) => slot.slot == _selectedSlot!.slot).firstOrNull;
    final selectedSlot = recalculatedSelectedSlot?.isEnabled == true
        ? recalculatedSelectedSlot
        : null;
    final canSubmit = canBook && selectedSlot != null;

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
            if (_statusMessage != null) ...[
              FocusStatusMessage(message: _statusMessage!, type: _statusType),
              const SizedBox(height: 18),
            ],
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useGrid = constraints.maxWidth >= 420;
                      final options = [30, 45, 60]
                          .map((duration) {
                            final isEnabled =
                                activeBono != null &&
                                duration <= activeBono.minutosRestantes;
                            return _DurationOption(
                              duration: duration,
                              isSelected: _selectedDuration == duration,
                              isEnabled: isEnabled,
                              onTap: isEnabled
                                  ? () => setState(() {
                                      _selectedDuration = duration;
                                      _selectedSlot = null;
                                    })
                                  : null,
                            );
                          })
                          .toList(growable: false);

                      if (!useGrid) {
                        return Column(
                          children: [
                            for (final option in options) ...[
                              option,
                              if (option != options.last)
                                const SizedBox(height: 10),
                            ],
                          ],
                        );
                      }
                      return Row(
                        children: [
                          for (final option in options) ...[
                            Expanded(child: option),
                            if (option != options.last)
                              const SizedBox(width: 10),
                          ],
                        ],
                      );
                    },
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
                    _SlotGrid(
                      slots: slots,
                      selectedSlot: selectedSlot,
                      onSelected: (slot) =>
                          setState(() => _selectedSlot = slot),
                    ),
                  if (selectedSlot != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Elegida: ${selectedSlot.slot.dateLabel} a las ${selectedSlot.slot.time}',
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
            FocusPrimaryButton(
              label: 'Enviar Solicitud',
              isLoading: _isSubmitting,
              onPressed: canSubmit && !_isSubmitting ? _submit : null,
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

  void _handlePortalChange() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final state = widget.viewModel.state;
    final activeBono = state.activeBono;
    final selectedSlot = _selectedSlot;
    final siteConfig = state.siteConfig;
    if (siteConfig == null) {
      _showError('No hemos podido cargar la configuracion horaria del centro.');
      return;
    }
    if (activeBono == null) {
      _showError('No tienes un bono activo disponible.');
      return;
    }
    if (activeBono.minutosRestantes < _selectedDuration) {
      _showError('No tienes minutos suficientes para esta sesion.');
      return;
    }
    if (selectedSlot == null) {
      _showError('Selecciona una franja horaria.');
      return;
    }
    final latestSlot = bookingSlotState(
      slot: selectedSlot.slot,
      durationMinutes: _selectedDuration,
      siteConfig: siteConfig,
      blockedSlots: state.blockedSlots,
      occupancy: state.slotOccupancy,
      activeAppointments: state.activeAppointments,
    );
    if (!latestSlot.isEnabled) {
      _showError(_messageForDisabledSlot(latestSlot));
      setState(() => _selectedSlot = null);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });
    try {
      await widget.viewModel.createAppointment(
        durationMinutes: _selectedDuration,
        preferredSlot: latestSlot.slot,
        reason: _commentController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Solicitud Enviada';
        _statusType = FocusStatusType.success;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _showError(appointmentRequestErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    setState(() {
      _statusMessage = message;
      _statusType = FocusStatusType.error;
    });
  }

  String _messageForDisabledSlot(BookingSlotState slot) {
    return switch (slot.label) {
      'Pasado' => 'Elige una franja futura.',
      'No cabe' => 'Esta franja no cabe en el horario disponible.',
      'Bloqueado' => 'Esta franja ya no esta disponible.',
      'Completo' => 'Esta franja esta completa.',
      'Tu sesion' => 'Ya tienes una sesion en esa franja.',
      _ => 'Esta franja ya no esta disponible.',
    };
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

class _DurationOption extends StatelessWidget {
  const _DurationOption({
    required this.duration,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final int duration;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppTheme.emerald.withValues(alpha: 0.72)
        : AppTheme.borderStrong.withValues(alpha: 0.76);
    return Opacity(
      opacity: isEnabled ? 1 : 0.42,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.surfaceElevated.withValues(alpha: 0.96)
                : AppTheme.input,
            borderRadius: BorderRadius.circular(AppTheme.radiusInput),
            border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$duration',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 27,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.emerald,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'min',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected ? AppTheme.emerald : AppTheme.textSecondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.slots,
    required this.selectedSlot,
    required this.onSelected,
  });

  final List<BookingSlotState> slots;
  final BookingSlotState? selectedSlot;
  final ValueChanged<BookingSlotState> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (constraints.maxWidth) {
          < 340 => 2,
          < 560 => 3,
          _ => 4,
        };
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slots.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 74,
          ),
          itemBuilder: (context, index) {
            final slot = slots[index];
            final isSelected = selectedSlot?.slot == slot.slot;
            return _SlotChip(
              slot: slot,
              isSelected: isSelected,
              onTap: slot.isEnabled ? () => onSelected(slot) : null,
            );
          },
        );
      },
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
    return Opacity(
      opacity: slot.isEnabled ? 1 : 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
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
                      color: AppTheme.emerald.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  slot.slot.time,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  isSelected ? 'Elegida' : slot.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        _LegendItem(color: AppTheme.textSecondary, label: 'No cabe'),
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
