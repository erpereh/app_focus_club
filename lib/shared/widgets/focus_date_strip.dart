import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_text_size.dart';

class FocusDateStripItem {
  const FocusDateStripItem({
    required this.id,
    required this.weekday,
    required this.day,
  });

  final String id;
  final String weekday;
  final String day;
}

class FocusDateStrip extends StatelessWidget {
  const FocusDateStrip({
    required this.items,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<FocusDateStripItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final extent = AppTextSizing.dateExtent(context);
    return SizedBox(
      height: extent + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = item.id == selectedId;
          return _DateChip(
            item: item,
            selected: selected,
            extent: extent,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(item.id);
            },
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.item,
    required this.selected,
    required this.extent,
    required this.onTap,
  });

  final FocusDateStripItem item;
  final bool selected;
  final double extent;
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
          width: 72,
          height: extent,
          decoration: BoxDecoration(
            color: selected ? AppTheme.lime : AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.weekday,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? AppTheme.onLime : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.day,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? AppTheme.onLime : AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
