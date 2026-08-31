import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

class FocusSegmentOption<T> {
  const FocusSegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

class FocusSegmentedControl<T> extends StatelessWidget {
  const FocusSegmentedControl({
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    super.key,
  });

  final List<FocusSegmentOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: options.map((option) {
            final isSelected = option.value == selectedValue;

            return Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(option.value);
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: AnimatedContainer(
                  duration: AppTheme.motion,
                  curve: AppTheme.motionCurve,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.black : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Center(
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? AppTheme.onBlack
                            : AppTheme.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
