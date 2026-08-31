import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_text_size.dart';

class FocusBottomNav extends StatelessWidget {
  const FocusBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    required this.onBook,
    this.unreadCount,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onBook;
  final int? unreadCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.black,
          borderRadius: BorderRadius.circular(34),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              _NavItem(
                key: const Key('nav-home'),
                label: 'Inicio',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                isSelected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
              _NavItem(
                key: const Key('nav-appointments'),
                label: 'Citas',
                icon: Icons.event_note_outlined,
                selectedIcon: Icons.event_note_rounded,
                isSelected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
              _BookButton(onTap: onBook),
              _NavItem(
                key: const Key('nav-chat'),
                label: 'Chat',
                icon: Icons.chat_bubble_outline_rounded,
                selectedIcon: Icons.chat_bubble_rounded,
                isSelected: selectedIndex == 2,
                badgeCount: unreadCount,
                onTap: () => onSelected(2),
              ),
              _NavItem(
                key: const Key('nav-profile'),
                label: 'Perfil',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                isSelected: selectedIndex == 3,
                onTap: () => onSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookButton extends StatelessWidget {
  const _BookButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: 'Reservar Sesion',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('nav-book'),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: Ink(
              decoration: const BoxDecoration(
                color: AppTheme.lime,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(
                dimension: 46,
                child: Icon(Icons.add_rounded, color: AppTheme.onLime, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
    super.key,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final minHeight = AppTextSizing.navigationItemMinHeight(context);
    return Expanded(
      flex: isSelected ? 3 : 2,
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: label,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: AnimatedContainer(
              duration: AppTheme.motion,
              curve: AppTheme.motionCurve,
              constraints: BoxConstraints(minHeight: minHeight),
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 12 : 8,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.lime : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        isSelected ? selectedIcon : icon,
                        color: isSelected ? AppTheme.onLime : AppTheme.onBlack,
                        size: 22,
                      ),
                      if (badgeCount != null && badgeCount! > 0)
                        Positioned(
                          right: -8,
                          top: -6,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: AppTheme.lime,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              child: Text(
                                badgeCount! > 99 ? '99+' : '$badgeCount',
                                style: const TextStyle(
                                  color: AppTheme.onLime,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.onLime,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
