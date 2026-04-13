import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_section_header.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../shared/widgets/focus_text_field.dart';
import '../../../theme/app_theme.dart';
import '../data/mock_client_data.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _commentController = TextEditingController();
  int _selectedDuration = 45;
  String _selectedDate = MockClientData.bookingDates.first;
  BookingSlot? _selectedSlot;
  bool _sent = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slots = MockClientData.bookingSlots
        .where((slot) => slot.dateLabel == _selectedDate)
        .toList();

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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (_sent) ...[
              const FocusStatusMessage(
                message:
                    'Solicitud Enviada. Revisaremos la franja y te avisaremos.',
                type: FocusStatusType.success,
              ),
              const SizedBox(height: 16),
            ],
            _StepCard(
              title: 'Duracion',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${MockClientData.activePass.remainingMinutes} minutos disponibles en tu bono.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [30, 45, 60].map((duration) {
                      final isEnabled =
                          duration <=
                          MockClientData.activePass.remainingMinutes;
                      return ChoiceChip(
                        label: Text('$duration min'),
                        selected: _selectedDuration == duration,
                        onSelected: isEnabled
                            ? (_) =>
                                  setState(() => _selectedDuration = duration)
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _StepCard(
              title: 'Fecha',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: MockClientData.bookingDates.map((date) {
                  return ChoiceChip(
                    label: Text(date),
                    selected: _selectedDate == date,
                    onSelected: (_) => setState(() {
                      _selectedDate = date;
                      _selectedSlot = null;
                    }),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _StepCard(
              title: 'Franja horaria',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SlotLegend(),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: slots.map((slot) {
                      final isSelected = _selectedSlot == slot;
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
                    const SizedBox(height: 14),
                    Text(
                      'Elegida: $_selectedDate a las ${_selectedSlot!.timeLabel}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.emerald,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 18),
            FocusPrimaryButton(
              label: 'Enviar Solicitud',
              onPressed: _selectedSlot == null
                  ? null
                  : () => setState(() => _sent = true),
            ),
            const SizedBox(height: 10),
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
          const SizedBox(height: 10),
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

  final BookingSlot slot;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (slot.stateLabel) {
      'Disponible' => AppTheme.emerald,
      '1 plaza' => AppTheme.amber,
      'Tu sesion' => const Color(0xFF6AA7FF),
      'Completo' || 'Bloqueado' => AppTheme.danger,
      _ => AppTheme.textSecondary,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: slot.isEnabled ? 1 : 0.52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.emerald.withValues(alpha: 0.18)
                : AppTheme.input,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppTheme.emerald
                  : color.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot.timeLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  isSelected ? 'Elegida' : slot.stateLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected ? AppTheme.emerald : color,
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
