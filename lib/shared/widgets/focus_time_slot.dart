import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_text_size.dart';

class FocusTimeSlot extends StatelessWidget {
  const FocusTimeSlot({
    required this.time,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String time;
  final String label;
  final bool selected;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? AppTheme.lime
        : enabled
        ? AppTheme.white
        : AppTheme.backgroundSecondary;
    final foreground = selected
        ? AppTheme.onLime
        : enabled
        ? AppTheme.textPrimary
        : AppTheme.textSecondary;

    return Opacity(
      opacity: enabled || selected ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap();
                }
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: AnimatedContainer(
            duration: AppTheme.motion,
            curve: AppTheme.motionCurve,
            height: AppTextSizing.slotExtent(context),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: selected ? AppTheme.lime : color.withValues(alpha: 0.28),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  time,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selected ? 'Elegida' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? AppTheme.onLime : color,
                    letterSpacing: 0,
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
