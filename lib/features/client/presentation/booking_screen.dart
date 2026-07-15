import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_text_size.dart';
import '../application/client_portal_view_model.dart';
import '../data/portal_repository.dart';
import '../domain/portal_models.dart';
import '../widgets/appointment_display.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    required this.viewModel,
    this.editingAppointment,
    super.key,
  });

  final ClientPortalViewModel viewModel;
  final Appointment? editingAppointment;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _commentController = TextEditingController();
  late int _selectedDuration;
  late String _selectedDate;
  BookingSlotState? _selectedSlot;
  String? _statusMessage;
  FocusStatusType _statusType = FocusStatusType.success;
  bool _isSubmitting = false;

  bool get _isEditing => widget.editingAppointment != null;

  @override
  void initState() {
    super.initState();
    final editingSlot = widget.editingAppointment?.schedulingSlot;
    final isFutureEditingSlot =
        editingSlot != null &&
        (appointmentSlotDateTime(editingSlot)?.isAfter(DateTime.now()) ??
            false);
    _selectedDuration = widget.editingAppointment?.durationMinutes ?? 45;
    _selectedDate = isFutureEditingSlot
        ? editingSlot.date
        : buildBookingDates().first;
    if (isFutureEditingSlot) {
      _selectedSlot = BookingSlotState(
        slot: editingSlot,
        label: 'Disponible',
        color: AppTheme.emerald,
        isEnabled: true,
      );
    }
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
    final editingSlot = widget.editingAppointment?.schedulingSlot;
    final dates = {
      ...buildBookingDates(),
      if (_isEditing &&
          editingSlot != null &&
          (appointmentSlotDateTime(editingSlot)?.isAfter(DateTime.now()) ??
              false))
        editingSlot.date,
    }.toList(growable: false)..sort();
    final canBook = _isEditing
        ? siteConfig != null
        : activeBono?.canBook == true &&
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
                  excludedAppointmentId: widget.editingAppointment?.id,
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

    return AppTextSizing.region(
      context,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Modificar cita' : 'Reservar Sesion'),
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
                      _isEditing
                          ? 'La duración de esta cita se mantiene en $_selectedDuration min.'
                          : activeBono == null
                          ? 'No hay bono activo disponible para reservar.'
                          : '${activeBono.minutosRestantes} minutos disponibles en tu bono.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    if (_isEditing)
                      Text(
                        'Duración fija: $_selectedDuration min',
                        style: Theme.of(context).textTheme.titleSmall,
                      )
                    else
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
              if (_isEditing &&
                  widget.editingAppointment?.status ==
                      AppointmentStatus.approved) ...[
                const FocusStatusMessage(
                  message:
                      'Al cambiar la franja, la cita volverá a quedar pendiente de aprobación.',
                  type: FocusStatusType.warning,
                ),
                const SizedBox(height: 18),
              ],
              if (!_isEditing) ...[
                _CommentInputCard(controller: _commentController),
                const SizedBox(height: 22),
              ],
              FocusPrimaryButton(
                label: _isEditing ? 'Guardar cambios' : 'Enviar Solicitud',
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
    if (!_isEditing && activeBono == null) {
      _showError('No tienes un bono activo disponible.');
      return;
    }
    if (!_isEditing && activeBono!.minutosRestantes < _selectedDuration) {
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
      excludedAppointmentId: widget.editingAppointment?.id,
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
      if (_isEditing) {
        await widget.viewModel.updateAppointmentSlot(
          appointmentId: widget.editingAppointment!.id,
          preferredSlot: latestSlot.slot,
        );
      } else {
        await widget.viewModel.createAppointment(
          durationMinutes: _selectedDuration,
          preferredSlot: latestSlot.slot,
          reason: _commentController.text.trim(),
        );
      }
      if (!mounted) return;
      setState(() {
        _statusMessage = _isEditing ? 'Cambios guardados' : 'Solicitud Enviada';
        _statusType = FocusStatusType.success;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        final navigator = Navigator.of(context);
        if (_isEditing) {
          navigator.popUntil((route) => route.isFirst);
        } else {
          navigator.pop();
        }
      }
    } catch (error) {
      if (!mounted) return;
      _showError(
        _isEditing
            ? appointmentMutationErrorMessage(error)
            : appointmentRequestErrorMessage(error),
      );
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
      'No disponible' =>
        'Esta franja no está disponible para esta duración o restricción.',
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

class _CommentInputCard extends StatelessWidget {
  const _CommentInputCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return FocusGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const SizedBox.square(
                  dimension: 38,
                  child: Icon(
                    Icons.notes_rounded,
                    color: AppTheme.emerald,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Comentario opcional',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Comentario opcional',
              hintText: 'Cuentanos si necesitas adaptar la sesion.',
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 56),
                child: Icon(Icons.edit_note_rounded, size: 20),
              ),
              filled: true,
              fillColor: AppTheme.input.withValues(alpha: 0.80),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                borderSide: BorderSide(
                  color: AppTheme.borderStrong.withValues(alpha: 0.52),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                borderSide: BorderSide(
                  color: AppTheme.emerald.withValues(alpha: 0.62),
                  width: 1.2,
                ),
              ),
            ),
          ),
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
        ? AppTheme.emerald.withValues(alpha: 0.32)
        : AppTheme.borderStrong.withValues(alpha: 0.42);
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
                      color: Colors.black.withValues(alpha: 0.22),
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
        return GridView.builder(
          key: const Key('booking-slot-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slots.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: AppTextSizing.slotExtent(context),
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
                  ? AppTheme.emerald.withValues(alpha: 0.24)
                  : AppTheme.borderStrong.withValues(alpha: 0.24),
              width: isSelected ? 1.2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                  maxLines: 2,
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
          mainAxisExtent: AppTextSizing.dateExtent(context),
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
                        ? AppTheme.emerald.withValues(alpha: 0.24)
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
        _LegendItem(color: AppTheme.textSecondary, label: 'No disponible'),
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
