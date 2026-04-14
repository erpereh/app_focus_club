import 'package:flutter/material.dart';

import '../../features/client/domain/portal_models.dart';
import '../../features/client/widgets/appointment_display.dart';
import '../../theme/app_theme.dart';

class FocusStatusBadge extends StatelessWidget {
  const FocusStatusBadge({required this.label, required this.color, super.key});

  factory FocusStatusBadge.appointment(AppointmentStatus status) {
    return FocusStatusBadge(
      label: appointmentStatusLabel(status),
      color: appointmentStatusColor(status),
    );
  }

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusBadge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
