import 'package:flutter/material.dart';

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
        color: AppTheme.input.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(
          color: AppTheme.borderStrong.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: options.map((option) {
            final isSelected = option.value == selectedValue;

            return Expanded(
              child: InkWell(
                onTap: () => onChanged(option.value),
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.surfaceElevated.withValues(alpha: 0.94)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.emerald.withValues(alpha: 0.24)
                          : Colors.transparent,
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
                  child: Center(
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
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
