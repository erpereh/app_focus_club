import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';
import '../domain/recurring_booking.dart';
import '../domain/recurring_booking_availability.dart';

const recurringHastaLoadingMessage = 'Comprobando disponibilidad...';
const recurringHastaPreviewErrorMessage =
    'No se ha podido comprobar la disponibilidad.';
const recurringHastaPreviewErrorHint =
    'No se ha podido comprobar la disponibilidad. Se volverá a validar al enviar.';
const recurringHastaCheckedMessage = 'Disponibilidad comprobada';

class RecurringHastaSelect extends StatelessWidget {
  const RecurringHastaSelect({
    required this.hasta,
    required this.selectedEndDate,
    required this.phase,
    required this.statuses,
    required this.onEndDateChanged,
    super.key,
  });

  final RecurringHastaViewModel hasta;
  final String? selectedEndDate;
  final RecurringHastaAvailabilityPhase phase;
  final List<RecurringHastaOptionStatus> statuses;
  final ValueChanged<String?> onEndDateChanged;

  RecurringHastaOptionStatus? _statusFor(String endDate) {
    return statuses.where((item) => item.option.endDate == endDate).firstOrNull;
  }

  bool _canSelect(String endDate) {
    if (phase == RecurringHastaAvailabilityPhase.loading) return false;
    if (phase == RecurringHastaAvailabilityPhase.error || statuses.isEmpty) {
      return true;
    }
    return _statusFor(endDate)?.isAvailable == true;
  }

  Future<void> _openSheet(BuildContext context) async {
    HapticFeedback.selectionClick();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusHero),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Hasta',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (phase == RecurringHastaAvailabilityPhase.loading)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: Text(recurringHastaLoadingMessage),
                    ),
                  if (phase == RecurringHastaAvailabilityPhase.error)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: Text(
                        recurringHastaPreviewErrorMessage,
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(color: AppTheme.warning),
                      ),
                    ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: hasta.options.length,
                      itemBuilder: (context, index) {
                        final option = hasta.options[index];
                        final status = _statusFor(option.endDate);
                        final selectable = _canSelect(option.endDate);
                        final selected = option.endDate == selectedEndDate;
                        final showAvailable =
                            phase == RecurringHastaAvailabilityPhase.ready &&
                            status?.isAvailable == true;
                        final showProblem =
                            phase == RecurringHastaAvailabilityPhase.ready &&
                            status != null &&
                            !status.isAvailable;
                        return ListTile(
                          key: Key('recurring-hasta-option-${option.endDate}'),
                          enabled: selectable,
                          selected: selected,
                          title: Text(formatIsoDateEs(option.endDate)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${option.occurrenceCount} sesiones · ${option.totalMinutes} min',
                              ),
                              if (showAvailable)
                                Text(
                                  'Disponible',
                                  style: TextStyle(color: AppTheme.success),
                                ),
                              if (showProblem && status.message != null)
                                Text(
                                  status.message!,
                                  style: const TextStyle(
                                    color: AppTheme.warning,
                                  ),
                                ),
                            ],
                          ),
                          trailing: showAvailable
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppTheme.success,
                                )
                              : showProblem
                              ? const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppTheme.warning,
                                )
                              : null,
                          onTap: selectable
                              ? () => Navigator.of(
                                  sheetContext,
                                ).pop(option.endDate)
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected != null) onEndDateChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (hasta.options.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedOption = hasta.options
        .where((option) => option.endDate == selectedEndDate)
        .firstOrNull;
    final label = selectedOption == null
        ? 'Selecciona una fecha'
        : formatRecurringHastaOptionLabel(selectedOption);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppTheme.input,
          borderRadius: BorderRadius.circular(AppTheme.radiusInput),
          child: InkWell(
            key: const Key('recurring-end-date'),
            borderRadius: BorderRadius.circular(AppTheme.radiusInput),
            onTap: () => _openSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: selectedOption == null
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (phase == RecurringHastaAvailabilityPhase.loading) ...[
          const SizedBox(height: 10),
          Text(
            recurringHastaLoadingMessage,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
        if (phase == RecurringHastaAvailabilityPhase.error) ...[
          const SizedBox(height: 10),
          Text(
            recurringHastaPreviewErrorMessage,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.warning),
          ),
        ],
      ],
    );
  }
}
