import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_date_strip.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../shared/widgets/focus_time_slot.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_text_size.dart';
import '../application/client_portal_view_model.dart';
import '../data/portal_repository.dart';
import '../domain/madrid_date.dart';
import '../domain/portal_availability.dart';
import '../domain/portal_models.dart';
import '../domain/recurring_booking.dart';
import '../domain/recurring_booking_availability.dart';
import '../widgets/appointment_display.dart';
import '../widgets/recurring_hasta_select.dart';

enum _BookingType { single, recurring }

enum _BookingStep { type, duration, schedule, recurrence, summary }

enum BookingEditMode {
  none,
  singleAppointment,
  recurringSingle,
  recurringSeries,
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    required this.viewModel,
    this.editMode = BookingEditMode.none,
    this.sourceAppointment,
    this.sourceSeries,
    super.key,
  }) : assert(
         editMode == BookingEditMode.none
             ? sourceAppointment == null && sourceSeries == null
             : sourceAppointment != null,
       ),
       assert(
         editMode == BookingEditMode.recurringSeries
             ? sourceSeries != null
             : sourceSeries == null,
       );

  final ClientPortalViewModel viewModel;
  final BookingEditMode editMode;
  final Appointment? sourceAppointment;
  final RecurringAppointmentSeries? sourceSeries;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _commentController = TextEditingController();
  final _intervalController = TextEditingController(
    text: '$defaultRecurringIntervalDays',
  );
  late int _selectedDuration;
  late String _selectedDate;
  BookingSlotState? _selectedSlot;
  String? _statusMessage;
  FocusStatusType _statusType = FocusStatusType.success;
  bool _isSubmitting = false;
  _BookingType _bookingType = _BookingType.single;
  int _intervalDays = defaultRecurringIntervalDays;
  String? _selectedEndDate;
  int _stepIndex = 0;
  RecurringHastaAvailabilityPhase _hastaPhase =
      RecurringHastaAvailabilityPhase.idle;
  List<RecurringHastaOptionStatus> _hastaStatuses = const [];
  int _hastaGeneration = 0;
  List<String>? _cachedAvailabilityDates;
  RecurringAvailabilitySnapshot? _cachedAvailabilitySnapshot;

  bool get _isEditing => widget.editMode != BookingEditMode.none;
  bool get _isRecurringSingle =>
      widget.editMode == BookingEditMode.recurringSingle;
  bool get _isRecurringSeries =>
      widget.editMode == BookingEditMode.recurringSeries;
  bool get _isRecurringBooking =>
      _isRecurringSeries ||
      (!_isEditing && _bookingType == _BookingType.recurring);

  Appointment? _liveEditingAppointment() {
    final original = widget.sourceAppointment;
    if (original == null) return null;
    return resolveLiveAppointment(
      fallback: original,
      appointments: widget.viewModel.state.appointments,
    );
  }

  List<_BookingStep> get _flow {
    if (_isRecurringSeries) {
      return const [
        _BookingStep.schedule,
        _BookingStep.recurrence,
        _BookingStep.summary,
      ];
    }
    if (_isEditing) {
      return const [_BookingStep.schedule, _BookingStep.summary];
    }
    if (_isRecurringBooking) {
      return const [
        _BookingStep.type,
        _BookingStep.duration,
        _BookingStep.schedule,
        _BookingStep.recurrence,
        _BookingStep.summary,
      ];
    }
    return const [
      _BookingStep.type,
      _BookingStep.duration,
      _BookingStep.schedule,
      _BookingStep.summary,
    ];
  }

  _BookingStep get _currentStep {
    final flow = _flow;
    return flow[_stepIndex.clamp(0, flow.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    final editingSlot = _initialEditingSlot();
    final isFutureEditingSlot =
        editingSlot != null &&
        isMadridSlotFuture(
          date: editingSlot.date,
          time: editingSlot.time,
          now: widget.viewModel.currentTime,
        );
    _selectedDuration =
        widget.sourceSeries?.durationMinutes ??
        widget.sourceAppointment?.durationMinutes ??
        45;
    if (_isRecurringSeries) {
      _intervalDays = widget.sourceSeries!.intervalDays;
      _intervalController.text = '$_intervalDays';
      _selectedEndDate = _initialSeriesEndDate();
    }
    _selectedDate = isFutureEditingSlot
        ? editingSlot.date
        : buildBookingDates(now: widget.viewModel.currentTime).first;
    if (isFutureEditingSlot) {
      _selectedSlot = BookingSlotState(
        slot: editingSlot,
        availability: BookingSlotAvailability.available,
        occupied: 0,
        remaining: widget.viewModel.state.siteConfig?.maxCapacity ?? 0,
        maxCapacity: widget.viewModel.state.siteConfig?.maxCapacity ?? 0,
        label: 'Disponible',
      );
    }
    widget.viewModel.addListener(_handlePortalChange);
  }

  List<Appointment> _replacedOccurrences(ClientPortalState state) {
    final series = widget.sourceSeries;
    if (!_isRecurringSeries || series == null) {
      final appointment = _liveEditingAppointment();
      return appointment == null ? const [] : [appointment];
    }
    return futureActiveOccurrencesForSeries(
      seriesId: series.id,
      appointments: state.appointments,
      now: widget.viewModel.currentTime,
    );
  }

  Set<String> _excludedAppointmentIds(ClientPortalState state) =>
      _replacedOccurrences(state).map((item) => item.id).toSet();

  Map<String, int> _occupancyCredits(ClientPortalState state) =>
      buildOccupancyCreditsByKey(_replacedOccurrences(state));

  Bono? _replacementBono(ClientPortalState state) {
    final bonoId = widget.sourceSeries?.bonoId;
    if (bonoId == null) return state.activeBono;
    return state.bonos.where((item) => item.id == bonoId).firstOrNull;
  }

  RecurringSeriesReplacementBonoPolicy _replacementBonoPolicy(
    ClientPortalState state,
  ) {
    return recurringSeriesReplacementBonoPolicy(
      bono: _replacementBono(state),
      seriesId: widget.sourceSeries!.id,
      appointments: state.appointments,
      now: widget.viewModel.currentTime,
    );
  }

  TimeSlot? _initialEditingSlot() {
    if (!_isRecurringSeries) return widget.sourceAppointment?.schedulingSlot;
    final series = widget.sourceSeries!;
    final futureSlot =
        series.futureStartDate == null || series.futureStartTime == null
        ? null
        : TimeSlot(
            date: series.futureStartDate!,
            time: series.futureStartTime!,
          );
    if (futureSlot != null &&
        isMadridSlotFuture(
          date: futureSlot.date,
          time: futureSlot.time,
          now: widget.viewModel.currentTime,
        )) {
      return futureSlot;
    }
    final occurrences = futureActiveOccurrencesForSeries(
      seriesId: series.id,
      appointments: widget.viewModel.state.appointments,
      now: widget.viewModel.currentTime,
    );
    return occurrences.firstOrNull?.schedulingSlot ??
        widget.sourceAppointment?.schedulingSlot;
  }

  String? _initialSeriesEndDate() {
    final series = widget.sourceSeries!;
    final preferred = series.futureEndDate;
    if (preferred != null && isIsoDate(preferred)) return preferred;
    return isIsoDate(series.endDate) ? series.endDate : null;
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
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.viewModel.state;
    final now = widget.viewModel.currentTime;
    final activeBono = state.activeBono;
    final replacementBonoPolicy = _isRecurringSeries
        ? _replacementBonoPolicy(state)
        : null;
    final siteConfig = state.siteConfig;
    final liveEditingAppointment = _liveEditingAppointment();
    final editingSlot = liveEditingAppointment?.schedulingSlot;
    final dates = {
      ...buildBookingDates(now: now),
      if (_isEditing &&
          editingSlot != null &&
          isMadridSlotFuture(
            date: editingSlot.date,
            time: editingSlot.time,
            now: now,
          ))
        editingSlot.date,
    }.toList(growable: false)..sort();
    final canBook = _isRecurringSeries
        ? siteConfig != null && replacementBonoPolicy!.isAvailable
        : _isEditing
        ? siteConfig != null
        : activeBono?.canBook == true &&
              siteConfig != null &&
              _selectedDuration <= (activeBono?.minutosRestantes ?? 0);
    final excludedAppointmentIds = _excludedAppointmentIds(state);
    final occupancyCreditsByKey = _occupancyCredits(state);
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
                  appointments: state.appointments,
                  excludedAppointmentIds: excludedAppointmentIds,
                  occupancyCreditsByKey: occupancyCreditsByKey,
                  enforceRescheduleLeadTime: _isEditing,
                  now: now,
                ),
              )
              .toList(growable: false);
    final recalculatedSelectedSlot = _selectedSlot == null
        ? null
        : slots.where((slot) => slot.slot == _selectedSlot!.slot).firstOrNull;
    final selectedSlot = recalculatedSelectedSlot?.isEnabled == true
        ? recalculatedSelectedSlot
        : null;
    final hasta = _currentHasta(state);
    final selectedEndDate = sanitizeRecurringEndDateByAvailability(
      selectedEndDate: sanitizeRecurringEndDate(
        _selectedEndDate,
        hasta.options,
      ),
      statuses: _hastaStatuses,
      phase: _hastaPhase,
    );
    final selectedStatus = selectedEndDate == null
        ? null
        : _hastaStatuses
              .where((item) => item.option.endDate == selectedEndDate)
              .firstOrNull;
    final selectedEndDateInvalid =
        _hastaPhase == RecurringHastaAvailabilityPhase.ready &&
        selectedEndDate != null &&
        selectedStatus?.isAvailable != true;
    final canSubmitRecurring =
        !_isRecurringBooking ||
        (selectedEndDate != null &&
            _intervalDays >= 1 &&
            _hastaPhase != RecurringHastaAvailabilityPhase.loading &&
            !selectedEndDateInvalid);
    final sourceCanBeEdited = switch (widget.editMode) {
      BookingEditMode.none => true,
      BookingEditMode.singleAppointment || BookingEditMode.recurringSingle =>
        liveEditingAppointment != null &&
            canCustomerRescheduleAppointment(liveEditingAppointment, now),
      BookingEditMode.recurringSeries => canCustomerReplaceRecurringSeries(
        seriesId: widget.sourceSeries!.id,
        appointments: state.appointments,
        now: now,
      ),
    };
    final canSubmit =
        sourceCanBeEdited &&
        canBook &&
        selectedSlot != null &&
        canSubmitRecurring;
    final flow = _flow;
    final step = _currentStep;
    final canContinue = switch (step) {
      _BookingStep.type || _BookingStep.duration => true,
      _BookingStep.schedule => selectedSlot != null && canBook,
      _BookingStep.recurrence =>
        _hastaPhase != RecurringHastaAvailabilityPhase.loading &&
            !selectedEndDateInvalid,
      _BookingStep.summary => false,
    };

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _isRecurringSeries
              ? 'Modificar serie'
              : _isEditing
              ? 'Modificar cita'
              : 'Reservar Sesion',
        ),
        leading: IconButton(
          tooltip: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _StepDots(
                current: _stepIndex.clamp(0, flow.length - 1),
                total: flow.length,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  if (_statusMessage != null) ...[
                    FocusStatusMessage(
                      message: _statusMessage!,
                      type: _statusType,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (_isEditing && !sourceCanBeEdited) ...[
                    FocusStatusMessage(
                      message: _isRecurringSeries
                          ? 'Una de las sesiones de esta serie ya está dentro del plazo de 24 horas previo y no puede reprogramarse toda la serie.'
                          : 'Esta cita ya está dentro del plazo de 24 horas previo al entrenamiento y no puede modificarse.',
                      type: FocusStatusType.warning,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (_isRecurringSeries &&
                      replacementBonoPolicy?.isAvailable == false) ...[
                    const FocusStatusMessage(
                      message: 'El bono asociado ya no está disponible.',
                      type: FocusStatusType.warning,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (_isEditing && step == _BookingStep.schedule) ...[
                    const FocusStatusMessage(
                      message:
                          'El nuevo horario debe comenzar dentro de más de 24 horas.',
                      type: FocusStatusType.warning,
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (step == _BookingStep.type)
                    _TypeStep(
                      bookingType: _bookingType,
                      onChanged: _onBookingTypeChanged,
                    ),
                  if (step == _BookingStep.duration)
                    _DurationStep(
                      selectedDuration: _selectedDuration,
                      isEditing: _isEditing,
                      remainingMinutes: activeBono?.minutosRestantes,
                      onSelected: (duration) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedDuration = duration;
                          _selectedSlot = null;
                          _selectedEndDate = null;
                          _resetHastaPreview();
                        });
                        _requestHastaPreview();
                      },
                    ),
                  if (step == _BookingStep.schedule)
                    _ScheduleStep(
                      selectedDate: _selectedDate,
                      dates: dates,
                      slots: slots,
                      selectedSlot: selectedSlot,
                      canBook: canBook,
                      isRecurring: _isRecurringBooking,
                      showFixedDuration:
                          widget.editMode == BookingEditMode.singleAppointment,
                      durationMinutes: _selectedDuration,
                      onDateSelected: (date) {
                        setState(() {
                          _selectedDate = date;
                          _selectedSlot = null;
                          _selectedEndDate = null;
                          _resetHastaPreview();
                        });
                        _requestHastaPreview();
                      },
                      onSlotSelected: (slot) {
                        setState(() {
                          _selectedSlot = slot;
                          _selectedEndDate = null;
                          _resetHastaPreview();
                        });
                        _requestHastaPreview();
                      },
                    ),
                  if (step == _BookingStep.recurrence)
                    _RecurringControls(
                      intervalController: _intervalController,
                      intervalDays: _intervalDays,
                      hasta: hasta,
                      selectedEndDate: selectedEndDate,
                      durationMinutes: _selectedDuration,
                      phase: _hastaPhase,
                      statuses: _hastaStatuses,
                      onIntervalChanged: _onIntervalChanged,
                      onEndDateChanged: (endDate) => setState(() {
                        _selectedEndDate = endDate;
                      }),
                    ),
                  if (step == _BookingStep.summary)
                    _SummaryStep(
                      editMode: widget.editMode,
                      showApprovedEditWarning:
                          widget.editMode ==
                              BookingEditMode.singleAppointment &&
                          liveEditingAppointment?.status ==
                              AppointmentStatus.approved,
                      isRecurring: _isRecurringBooking,
                      durationMinutes: _selectedDuration,
                      selectedSlot: selectedSlot,
                      intervalDays: _intervalDays,
                      selectedEndDate: selectedEndDate,
                      hasta: hasta,
                      commentController: _commentController,
                      availabilityPhase: _hastaPhase,
                      availabilityChecked:
                          selectedStatus?.isAvailable == true &&
                          _hastaPhase == RecurringHastaAvailabilityPhase.ready,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  if (step == _BookingStep.summary)
                    FocusPrimaryButton(
                      label: _isEditing
                          ? 'Guardar cambios'
                          : 'Enviar Solicitud',
                      isLoading: _isSubmitting,
                      onPressed: canSubmit && !_isSubmitting
                          ? () {
                              HapticFeedback.lightImpact();
                              _submit();
                            }
                          : null,
                    )
                  else
                    FocusPrimaryButton(
                      label: 'Continuar',
                      onPressed: canContinue ? _goNext : null,
                    ),
                  const SizedBox(height: 10),
                  if (_stepIndex > 0)
                    FocusGhostButton(
                      label: 'Atras',
                      onPressed: _goBack,
                      icon: Icons.arrow_back_rounded,
                    )
                  else
                    FocusGhostButton(
                      label: 'Cancelar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icons.close_rounded,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goNext() {
    HapticFeedback.selectionClick();
    setState(() {
      _stepIndex = (_stepIndex + 1).clamp(0, _flow.length - 1);
    });
  }

  void _goBack() {
    setState(() {
      _stepIndex = (_stepIndex - 1).clamp(0, _flow.length - 1);
    });
  }

  void _handlePortalChange() {
    if (!mounted) return;
    setState(_syncRecurringEndDate);
    if (_hastaPhase == RecurringHastaAvailabilityPhase.loading ||
        _hastaPhase == RecurringHastaAvailabilityPhase.error) {
      return;
    }
    _requestHastaPreview();
  }

  void _onBookingTypeChanged(_BookingType type) {
    HapticFeedback.selectionClick();
    setState(() {
      _bookingType = type;
      if (type == _BookingType.single) {
        _selectedEndDate = null;
        _resetHastaPreview();
      } else {
        _syncRecurringEndDate();
      }
      _stepIndex = _stepIndex.clamp(0, _flow.length - 1);
    });
    _requestHastaPreview();
  }

  void _onIntervalChanged(String value) {
    final parsed = int.tryParse(value.trim());
    setState(() {
      _intervalDays = parsed != null && parsed >= 1 ? parsed : 0;
      _selectedEndDate = null;
      _resetHastaPreview();
    });
    _requestHastaPreview();
  }

  RecurringHastaViewModel _currentHasta(ClientPortalState state) {
    if (!_isRecurringSeries) {
      final bono = _replacementBono(state);
      return getRecurringHastaViewModel(
        startDate: _selectedDate,
        intervalDays: _intervalDays,
        durationMinutes: _selectedDuration,
        remainingMinutes: bono?.minutosRestantes ?? 0,
        bonoExpirationDate: bono?.fechaExpiracion,
      );
    }
    final replacementPolicy = _replacementBonoPolicy(state);
    return getRecurringHastaViewModel(
      startDate: _selectedDate,
      intervalDays: _intervalDays,
      durationMinutes: _selectedDuration,
      remainingMinutes: replacementPolicy.availableMinutes,
      bonoExpirationDate: replacementPolicy.expirationDate,
    );
  }

  void _syncRecurringEndDate() {
    _selectedEndDate = sanitizeRecurringEndDateByAvailability(
      selectedEndDate: sanitizeRecurringEndDate(
        _selectedEndDate,
        _currentHasta(widget.viewModel.state).options,
      ),
      statuses: _hastaStatuses,
      phase: _hastaPhase,
    );
  }

  void _resetHastaPreview() {
    _hastaGeneration += 1;
    _hastaPhase = RecurringHastaAvailabilityPhase.idle;
    _hastaStatuses = const [];
    _cachedAvailabilityDates = null;
    _cachedAvailabilitySnapshot = null;
  }

  bool _sameDates(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  void _requestHastaPreview() {
    if (!mounted) return;
    if (!_isRecurringBooking) {
      if (_hastaPhase != RecurringHastaAvailabilityPhase.idle ||
          _hastaStatuses.isNotEmpty) {
        setState(_resetHastaPreview);
      }
      return;
    }

    final state = widget.viewModel.state;
    final siteConfig = state.siteConfig;
    final time = _selectedSlot?.slot.time;
    final hasta = _currentHasta(state);
    if (siteConfig == null ||
        time == null ||
        hasta.options.isEmpty ||
        _intervalDays < 1) {
      if (_hastaPhase != RecurringHastaAvailabilityPhase.idle ||
          _hastaStatuses.isNotEmpty) {
        setState(_resetHastaPreview);
      }
      return;
    }

    final dates = generateRecurringOccurrenceDates(
      _selectedDate,
      _intervalDays,
      hasta.options.last.endDate,
    );
    final generation = ++_hastaGeneration;
    final cachedSnapshot = _cachedAvailabilitySnapshot;
    final cachedDates = _cachedAvailabilityDates;
    if (cachedSnapshot != null &&
        cachedDates != null &&
        _sameDates(cachedDates, dates)) {
      setState(() {
        _hastaPhase = RecurringHastaAvailabilityPhase.ready;
        _hastaStatuses = evaluateRecurringHastaOptions(
          startDate: _selectedDate,
          startTime: time,
          intervalDays: _intervalDays,
          durationMinutes: _selectedDuration,
          options: hasta.options,
          occupancy: cachedSnapshot.occupancyByKey,
          blockedKeys: cachedSnapshot.blockedKeys,
          appointments: state.appointments,
          excludedAppointmentIds: _excludedAppointmentIds(state),
          occupancyCreditsByKey: _occupancyCredits(state),
          enforceRescheduleLeadTime: _isEditing,
          siteConfig: siteConfig,
          now: widget.viewModel.currentTime,
        );
        _syncRecurringEndDate();
      });
      return;
    }

    setState(() {
      _hastaPhase = RecurringHastaAvailabilityPhase.loading;
      _hastaStatuses = const [];
    });
    unawaited(
      _loadHastaAvailability(
        generation: generation,
        dates: dates,
        startTime: time,
        hasta: hasta,
        siteConfig: siteConfig,
      ),
    );
  }

  Future<void> _loadHastaAvailability({
    required int generation,
    required List<String> dates,
    required String startTime,
    required RecurringHastaViewModel hasta,
    required SiteConfig siteConfig,
  }) async {
    try {
      final snapshot = await widget.viewModel.getAvailabilityForDates(dates);
      if (!mounted || generation != _hastaGeneration) return;
      final state = widget.viewModel.state;
      final currentConfig = state.siteConfig ?? siteConfig;
      setState(() {
        _cachedAvailabilityDates = dates;
        _cachedAvailabilitySnapshot = snapshot;
        _hastaPhase = RecurringHastaAvailabilityPhase.ready;
        _hastaStatuses = evaluateRecurringHastaOptions(
          startDate: _selectedDate,
          startTime: startTime,
          intervalDays: _intervalDays,
          durationMinutes: _selectedDuration,
          options: hasta.options,
          occupancy: snapshot.occupancyByKey,
          blockedKeys: snapshot.blockedKeys,
          appointments: state.appointments,
          excludedAppointmentIds: _excludedAppointmentIds(state),
          occupancyCreditsByKey: _occupancyCredits(state),
          enforceRescheduleLeadTime: _isEditing,
          siteConfig: currentConfig,
          now: widget.viewModel.currentTime,
        );
        _syncRecurringEndDate();
      });
    } catch (_) {
      if (!mounted || generation != _hastaGeneration) return;
      setState(() {
        _hastaPhase = RecurringHastaAvailabilityPhase.error;
        _hastaStatuses = const [];
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
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
    String? validatedEndDate;
    if (_isRecurringBooking) {
      validatedEndDate = sanitizeRecurringEndDate(
        _selectedEndDate,
        _currentHasta(state).options,
      );
      if (validatedEndDate == null || _intervalDays < 1) {
        _showError(
          'Selecciona hasta que fecha quieres repetir el entrenamiento.',
        );
        return;
      }
      if (_hastaPhase == RecurringHastaAvailabilityPhase.loading) {
        _showError('Espera a que termine la comprobación de disponibilidad.');
        return;
      }
      if (_hastaPhase == RecurringHastaAvailabilityPhase.ready) {
        final latestStatus = _hastaStatuses
            .where((item) => item.option.endDate == validatedEndDate)
            .firstOrNull;
        if (latestStatus?.isAvailable != true) {
          _showError(
            latestStatus?.message ??
                'Una de las sesiones seleccionadas ya no está disponible.',
          );
          return;
        }
      }
    }
    final now = widget.viewModel.currentTime;
    final latestSlot = bookingSlotState(
      slot: selectedSlot.slot,
      durationMinutes: _selectedDuration,
      siteConfig: siteConfig,
      blockedSlots: state.blockedSlots,
      occupancy: state.slotOccupancy,
      appointments: state.appointments,
      excludedAppointmentIds: _excludedAppointmentIds(state),
      occupancyCreditsByKey: _occupancyCredits(state),
      enforceRescheduleLeadTime: _isEditing,
      now: now,
    );
    if (!latestSlot.isEnabled) {
      _showError(_messageForDisabledSlot(latestSlot));
      setState(() => _selectedSlot = null);
      return;
    }
    final liveSource = _liveEditingAppointment();
    final sourceStillEditable = widget.editMode == BookingEditMode.none
        ? true
        : _isRecurringSeries
        ? canCustomerReplaceRecurringSeries(
            seriesId: widget.sourceSeries!.id,
            appointments: state.appointments,
            now: now,
          )
        : liveSource != null &&
              canCustomerRescheduleAppointment(liveSource, now);
    if (!sourceStillEditable) {
      _showError(
        _isRecurringSeries
            ? 'Una de las sesiones de esta serie ya está dentro del plazo de 24 horas previo y no puede reprogramarse toda la serie.'
            : 'Esta cita ya está dentro del plazo de 24 horas previo al entrenamiento y no puede modificarse.',
      );
      return;
    }
    if (_isRecurringSeries) {
      final liveReplacementPolicy = _replacementBonoPolicy(
        widget.viewModel.state,
      );
      if (!liveReplacementPolicy.isAvailable) {
        _showError('El bono asociado ya no está disponible.');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });
    try {
      if (widget.editMode == BookingEditMode.singleAppointment) {
        await widget.viewModel.updateAppointmentSlot(
          appointmentId: widget.sourceAppointment!.id,
          preferredSlot: latestSlot.slot,
        );
      } else if (_isRecurringSingle) {
        await widget.viewModel.rescheduleRecurringOccurrence(
          appointmentId: widget.sourceAppointment!.id,
          preferredSlot: latestSlot.slot,
        );
      } else if (_isRecurringSeries) {
        await widget.viewModel.replaceRecurringSeriesSchedule(
          appointmentId: widget.sourceAppointment!.id,
          startSlot: latestSlot.slot,
          intervalDays: _intervalDays,
          endDate: validatedEndDate!,
        );
      } else if (_isRecurringBooking) {
        await widget.viewModel.createRecurringAppointments(
          durationMinutes: _selectedDuration,
          preferredSlot: latestSlot.slot,
          intervalDays: _intervalDays,
          endDate: validatedEndDate!,
          reason: _commentController.text.trim(),
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
        _statusMessage = switch (widget.editMode) {
          BookingEditMode.recurringSingle =>
            'Cita modificada. Ha quedado pendiente de aprobación.',
          BookingEditMode.recurringSeries =>
            'Serie modificada. Las próximas sesiones han quedado pendientes de aprobación.',
          BookingEditMode.singleAppointment => 'Cambios guardados',
          BookingEditMode.none => 'Solicitud Enviada',
        };
        _statusType = FocusStatusType.success;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      final message = switch (widget.editMode) {
        BookingEditMode.recurringSingle => recurringRescheduleErrorMessage(
          error,
          context: CustomerRescheduleErrorContext.single,
        ),
        BookingEditMode.recurringSeries => recurringRescheduleErrorMessage(
          error,
          context: CustomerRescheduleErrorContext.series,
        ),
        BookingEditMode.singleAppointment => appointmentMutationErrorMessage(
          error,
        ),
        BookingEditMode.none => appointmentRequestErrorMessage(error),
      };
      _showError(message);
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
    return switch (slot.availability) {
      BookingSlotAvailability.past => 'Elige una franja futura.',
      BookingSlotAvailability.unavailable =>
        'Esta franja no está disponible para esta duración o restricción.',
      BookingSlotAvailability.blocked => 'Esta franja ya no está disponible.',
      BookingSlotAvailability.full => 'Esta franja está completa.',
      BookingSlotAvailability.ownAppointment =>
        'Ya tienes una sesión en esa franja.',
      _ => 'Esta franja ya no esta disponible.',
    };
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: AppTheme.motion,
              height: 4,
              decoration: BoxDecoration(
                color: i <= current
                    ? AppTheme.black
                    : AppTheme.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
          ),
          if (i != total - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _TypeStep extends StatelessWidget {
  const _TypeStep({required this.bookingType, required this.onChanged});

  final _BookingType bookingType;
  final ValueChanged<_BookingType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tipo', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Elige si quieres una sesion suelta o un entrenamiento recurrente.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _BookingTypeOption(
          key: const Key('booking-type-single'),
          label: 'Cita única',
          detail: 'Una sola sesion',
          isSelected: bookingType == _BookingType.single,
          onTap: () => onChanged(_BookingType.single),
        ),
        const SizedBox(height: 12),
        _BookingTypeOption(
          key: const Key('booking-type-recurring'),
          label: 'Entrenamiento recurrente',
          detail: 'Repite cada X dias',
          isSelected: bookingType == _BookingType.recurring,
          onTap: () => onChanged(_BookingType.recurring),
        ),
      ],
    );
  }
}

class _BookingTypeOption extends StatelessWidget {
  const _BookingTypeOption({
    required this.label,
    required this.detail,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String detail;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: AnimatedContainer(
          duration: AppTheme.motion,
          curve: AppTheme.motionCurve,
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.lime : AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isSelected ? AppTheme.onLime : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? AppTheme.onLime.withValues(alpha: 0.72)
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationStep extends StatelessWidget {
  const _DurationStep({
    required this.selectedDuration,
    required this.isEditing,
    required this.remainingMinutes,
    required this.onSelected,
  });

  final int selectedDuration;
  final bool isEditing;
  final int? remainingMinutes;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duracion', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          remainingMinutes == null
              ? 'No hay bono activo disponible para reservar.'
              : '${formatMinutesDuration(remainingMinutes!)} disponibles',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (isEditing)
          Text(
            'Duración fija: $selectedDuration min',
            style: Theme.of(context).textTheme.titleSmall,
          )
        else
          Row(
            children: [
              for (final duration in [30, 45, 60]) ...[
                Expanded(
                  child: _DurationOption(
                    duration: duration,
                    isSelected: selectedDuration == duration,
                    isEnabled:
                        remainingMinutes != null &&
                        duration <= remainingMinutes!,
                    onTap:
                        remainingMinutes != null &&
                            duration <= remainingMinutes!
                        ? () => onSelected(duration)
                        : null,
                  ),
                ),
                if (duration != 60) const SizedBox(width: 10),
              ],
            ],
          ),
      ],
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
    return Opacity(
      opacity: isEnabled ? 1 : 0.42,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: AnimatedContainer(
          duration: AppTheme.motion,
          curve: AppTheme.motionCurve,
          constraints: const BoxConstraints(minHeight: 88),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.lime : AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$duration',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: isSelected ? AppTheme.onLime : AppTheme.textPrimary,
                ),
              ),
              Text(
                'min',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSelected ? AppTheme.onLime : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({
    required this.selectedDate,
    required this.dates,
    required this.slots,
    required this.selectedSlot,
    required this.canBook,
    required this.isRecurring,
    required this.showFixedDuration,
    required this.durationMinutes,
    required this.onDateSelected,
    required this.onSlotSelected,
  });

  final String selectedDate;
  final List<String> dates;
  final List<BookingSlotState> slots;
  final BookingSlotState? selectedSlot;
  final bool canBook;
  final bool isRecurring;
  final bool showFixedDuration;
  final int durationMinutes;
  final ValueChanged<String> onDateSelected;
  final ValueChanged<BookingSlotState> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final selectedDateTime = DateTime.tryParse(selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRecurring ? 'Fecha inicial' : 'Fecha y hora',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        if (showFixedDuration)
          Text(
            'Duración fija: $durationMinutes min',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        if (showFixedDuration) const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedDateTime == null
                    ? 'Calendario'
                    : '${_monthLabel(selectedDateTime.month)} ${selectedDateTime.year}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: () => _openCalendar(context),
              child: const Text('Ver calendario'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FocusDateStrip(
          selectedId: selectedDate,
          onSelected: onDateSelected,
          items: [
            for (final date in dates)
              FocusDateStripItem(
                id: date,
                weekday: _stripWeekday(date),
                day: _chipDateLabel(date),
              ),
          ],
        ),
        const SizedBox(height: 24),
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
            onSelected: onSlotSelected,
          ),
        if (selectedSlot != null) ...[
          const SizedBox(height: 16),
          Text(
            'Elegida: ${selectedSlot!.slot.dateLabel} a las ${selectedSlot!.slot.time}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openCalendar(BuildContext context) async {
    final parsed = dates
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList(growable: false);
    if (parsed.isEmpty) return;
    final initial = DateTime.tryParse(selectedDate) ?? parsed.first;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: parsed.first,
      lastDate: parsed.last,
      selectableDayPredicate: (day) {
        final id =
            '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        return dates.contains(id);
      },
    );
    if (picked == null) return;
    final id =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (dates.contains(id)) onDateSelected(id);
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
    return GridView.builder(
      key: const Key('booking-slot-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: AppTextSizing.slotExtent(context),
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = selectedSlot?.slot == slot.slot;
        return FocusTimeSlot(
          time: slot.slot.time,
          label: slot.label,
          selected: isSelected,
          enabled: slot.isEnabled,
          color: bookingSlotColor(slot.availability),
          onTap: () => onSelected(slot),
        );
      },
    );
  }
}

class _RecurringControls extends StatelessWidget {
  const _RecurringControls({
    required this.intervalController,
    required this.intervalDays,
    required this.hasta,
    required this.selectedEndDate,
    required this.durationMinutes,
    required this.phase,
    required this.statuses,
    required this.onIntervalChanged,
    required this.onEndDateChanged,
  });

  final TextEditingController intervalController;
  final int intervalDays;
  final RecurringHastaViewModel hasta;
  final String? selectedEndDate;
  final int durationMinutes;
  final RecurringHastaAvailabilityPhase phase;
  final List<RecurringHastaOptionStatus> statuses;
  final ValueChanged<String> onIntervalChanged;
  final ValueChanged<String?> onEndDateChanged;

  @override
  Widget build(BuildContext context) {
    final selectedOption = hasta.options
        .where((option) => option.endDate == selectedEndDate)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recurrencia', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        Text('Cada', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            _StepperButton(
              icon: Icons.remove_rounded,
              onTap: () {
                final next = (intervalDays <= 1 ? 1 : intervalDays - 1);
                intervalController.text = '$next';
                onIntervalChanged('$next');
              },
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 84,
              child: TextFormField(
                key: const Key('recurring-interval-days'),
                controller: intervalController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onChanged: onIntervalChanged,
                style: Theme.of(context).textTheme.headlineMedium,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _StepperButton(
              icon: Icons.add_rounded,
              onTap: () {
                final next = intervalDays + 1;
                intervalController.text = '$next';
                onIntervalChanged('$next');
              },
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'días',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Hasta', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        if (hasta.options.isEmpty)
          FocusStatusMessage(
            message: recurringHastaEmptyMessage(hasta.emptyReason),
            type: FocusStatusType.warning,
          )
        else
          RecurringHastaSelect(
            hasta: hasta,
            selectedEndDate: selectedEndDate,
            phase: phase,
            statuses: statuses,
            onEndDateChanged: onEndDateChanged,
          ),
        if (selectedOption != null) ...[
          const SizedBox(height: 20),
          FocusBlackCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FocusKicker('Resumen', onDark: true),
                const SizedBox(height: 12),
                Text(
                  '${selectedOption.occurrenceCount} sesiones',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: AppTheme.onBlack),
                ),
                const SizedBox(height: 8),
                Text(
                  '$durationMinutes min por sesión',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onBlack.withValues(alpha: 0.72),
                  ),
                ),
                Text(
                  '${selectedOption.totalMinutes} min en total',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onBlack.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Las sesiones quedarán pendientes de aprobación.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onBlack.withValues(alpha: 0.72),
                  ),
                ),
                if (phase == RecurringHastaAvailabilityPhase.ready) ...[
                  const SizedBox(height: 8),
                  Text(
                    recurringHastaCheckedMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onBlack.withValues(alpha: 0.56),
                    ),
                  ),
                ],
                if (phase == RecurringHastaAvailabilityPhase.error) ...[
                  const SizedBox(height: 8),
                  Text(
                    recurringHastaPreviewErrorHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.warning.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: SizedBox.square(
          dimension: 48,
          child: Icon(icon, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({
    required this.editMode,
    required this.showApprovedEditWarning,
    required this.isRecurring,
    required this.durationMinutes,
    required this.selectedSlot,
    required this.intervalDays,
    required this.selectedEndDate,
    required this.hasta,
    required this.commentController,
    required this.availabilityPhase,
    required this.availabilityChecked,
  });

  final BookingEditMode editMode;
  final bool showApprovedEditWarning;
  final bool isRecurring;
  final int durationMinutes;
  final BookingSlotState? selectedSlot;
  final int intervalDays;
  final String? selectedEndDate;
  final RecurringHastaViewModel hasta;
  final TextEditingController commentController;
  final RecurringHastaAvailabilityPhase availabilityPhase;
  final bool availabilityChecked;

  @override
  Widget build(BuildContext context) {
    final option = hasta.options
        .where((item) => item.endDate == selectedEndDate)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          editMode == BookingEditMode.recurringSeries
              ? 'Modificar serie'
              : editMode == BookingEditMode.recurringSingle
              ? 'Modificar sesión'
              : 'Tu reserva',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        if (showApprovedEditWarning) ...[
          const FocusStatusMessage(
            message:
                'Al cambiar la franja, la cita volverá a quedar pendiente de aprobación.',
            type: FocusStatusType.warning,
          ),
          const SizedBox(height: 18),
        ],
        if (editMode == BookingEditMode.recurringSingle) ...[
          const FocusStatusMessage(
            message:
                'Después del cambio, la sesión quedará pendiente de aprobación.',
            type: FocusStatusType.warning,
          ),
          const SizedBox(height: 18),
        ],
        if (editMode == BookingEditMode.recurringSeries) ...[
          const FocusStatusMessage(
            message:
                'Las sesiones futuras modificadas quedarán pendientes de aprobación.',
            type: FocusStatusType.warning,
          ),
          const SizedBox(height: 18),
        ],
        SizedBox(
          width: double.infinity,
          child: FocusBlackCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FocusKicker(
                  editMode == BookingEditMode.recurringSeries
                      ? 'Modificar serie'
                      : editMode == BookingEditMode.recurringSingle
                      ? 'Modificar sesión'
                      : 'Tu reserva',
                  onDark: true,
                ),
                const SizedBox(height: 16),
                Text(
                  '$durationMinutes min',
                  style: Theme.of(
                    context,
                  ).textTheme.displaySmall?.copyWith(color: AppTheme.onBlack),
                ),
                const SizedBox(height: 12),
                Text(
                  selectedSlot == null
                      ? 'Selecciona fecha y hora'
                      : '${selectedSlot!.slot.dateLabel}\n${selectedSlot!.slot.time}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: AppTheme.onBlack),
                ),
                if (isRecurring && option != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Cada $intervalDays días · ${option.occurrenceCount} sesiones',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onBlack.withValues(alpha: 0.72),
                    ),
                  ),
                  Text(
                    '${option.totalMinutes} min total',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onBlack.withValues(alpha: 0.72),
                    ),
                  ),
                  if (availabilityChecked) ...[
                    const SizedBox(height: 8),
                    Text(
                      recurringHastaCheckedMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onBlack.withValues(alpha: 0.56),
                      ),
                    ),
                  ],
                  if (availabilityPhase ==
                      RecurringHastaAvailabilityPhase.error) ...[
                    const SizedBox(height: 8),
                    Text(
                      recurringHastaPreviewErrorHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.warning.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (editMode == BookingEditMode.none) ...[
          const SizedBox(height: 18),
          _CommentInputCard(controller: commentController),
        ],
      ],
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
          Text(
            'Comentario opcional',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Comentario opcional',
              hintText: 'Cuentanos si necesitas adaptar la sesion.',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
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

String _stripWeekday(String date) {
  final dateTime = DateTime.tryParse(date);
  if (dateTime == null) return '';
  return _weekdayLabel(dateTime.weekday).toUpperCase();
}

String _chipDateLabel(String date) {
  final dateTime = DateTime.tryParse(date);
  if (dateTime == null) return date;
  return '${dateTime.day.toString().padLeft(2, '0')} ${_monthLabel(dateTime.month)}';
}
