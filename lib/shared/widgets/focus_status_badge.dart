import 'package:flutter/material.dart';

import '../../features/client/data/mock_client_data.dart';
import '../../theme/app_theme.dart';

class FocusStatusBadge extends StatelessWidget {
  const FocusStatusBadge({required this.label, required this.color, super.key});

  factory FocusStatusBadge.appointment(AppointmentStatus status) {
    return FocusStatusBadge(
      label: switch (status) {
        AppointmentStatus.pending => 'Pendiente',
        AppointmentStatus.approved => 'Aprobada',
        AppointmentStatus.rejected => 'Rechazada',
      },
      color: switch (status) {
        AppointmentStatus.pending => AppTheme.amber,
        AppointmentStatus.approved => AppTheme.emerald,
        AppointmentStatus.rejected => AppTheme.danger,
      },
    );
  }

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
