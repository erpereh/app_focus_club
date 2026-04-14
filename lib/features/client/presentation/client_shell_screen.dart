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
  const ClientShellScreen({super.key});

  @override
  State<ClientShellScreen> createState() => _ClientShellScreenState();
}

class _ClientShellScreenState extends State<ClientShellScreen> {
  int _selectedIndex = 0;
  ClientPortalViewModel? _viewModel;
  String? _uid;

  void _selectTab(int index) => setState(() => _selectedIndex = index);

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

  void _openBooking(ClientPortalState state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => BookingScreen(state: state)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF06100D), AppTheme.background],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 112),
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
                          onOpenBooking: () => _openBooking(state),
                        ),
                        AppointmentsScreen(
                          state: state,
                          onOpenBooking: () => _openBooking(state),
                        ),
                        ProfileScreen(state: state),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 20,
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
        color: AppTheme.background.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppTheme.borderStrong.withValues(alpha: 0.34),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 22,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.surfaceElevated.withValues(alpha: 0.78)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            border: Border.all(
              color: isSelected
                  ? AppTheme.emerald.withValues(alpha: 0.22)
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
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
