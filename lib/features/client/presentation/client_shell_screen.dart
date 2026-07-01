import 'dart:ui';

import 'package:flutter/material.dart';

import '../../auth/application/auth_scope.dart';
import '../application/client_portal_view_model.dart';
import '../application/portal_scope.dart';
import '../../../theme/app_theme.dart';
import 'appointments_screen.dart';
import 'booking_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';

class ClientShellScreen extends StatefulWidget {
  const ClientShellScreen({this.initialTabIndex = 0, super.key});

  final int initialTabIndex;

  @override
  State<ClientShellScreen> createState() => _ClientShellScreenState();
}

class _ClientShellScreenState extends State<ClientShellScreen> {
  late int _selectedIndex;
  ClientPortalViewModel? _viewModel;
  String? _uid;

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex.clamp(0, 2);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = AuthScope.of(context).currentSession;
    final uid = session?.uid;
    if (uid == null || uid == _uid) return;

    _viewModel?.dispose();
    _uid = uid;
    _viewModel = ClientPortalViewModel(
      repository: PortalScope.of(context),
      uid: uid,
    )..start();
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  void _openBooking(ClientPortalViewModel viewModel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingScreen(viewModel: viewModel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A0D0B), AppTheme.background],
                ),
              ),
              child: ListenableBuilder(
                listenable: viewModel,
                builder: (context, _) {
                  final state = viewModel.state;
                  return IndexedStack(
                    index: _selectedIndex,
                    children: [
                      DashboardScreen(
                        state: state,
                        onOpenAppointments: () => _selectTab(1),
                        onOpenProfile: () => _selectTab(2),
                        onOpenBooking: () => _openBooking(viewModel),
                      ),
                      AppointmentsScreen(
                        state: state,
                        onOpenBooking: () => _openBooking(viewModel),
                      ),
                      ProfileScreen(state: state),
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _FloatingNavBar(
                selectedIndex: _selectedIndex,
                onSelected: _selectTab,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  _FloatingNavItem(
                    label: 'Inicio',
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    isSelected: selectedIndex == 0,
                    onTap: () => onSelected(0),
                  ),
                  _FloatingNavItem(
                    label: 'Citas',
                    icon: Icons.event_note_outlined,
                    selectedIcon: Icons.event_note_rounded,
                    isSelected: selectedIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                  _FloatingNavItem(
                    label: 'Perfil',
                    icon: Icons.person_outline_rounded,
                    selectedIcon: Icons.person_rounded,
                    isSelected: selectedIndex == 2,
                    onTap: () => onSelected(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.emeraldDark.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(
              color: isSelected
                  ? AppTheme.emerald.withValues(alpha: 0.12)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? AppTheme.emerald : AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSelected ? AppTheme.emerald : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
