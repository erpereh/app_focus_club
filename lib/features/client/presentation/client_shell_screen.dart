import 'package:flutter/material.dart';

import '../../auth/application/auth_scope.dart';
import '../application/client_portal_view_model.dart';
import '../application/portal_scope.dart';
import '../../../shared/widgets/focus_bottom_nav.dart';
import '../../../theme/app_theme.dart';
import '../../support/application/support_conversations_view_model.dart';
import '../../support/application/support_scope.dart';
import '../../support/presentation/support_list_screen.dart';
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

class _ClientShellScreenState extends State<ClientShellScreen>
    with WidgetsBindingObserver {
  late int _selectedIndex;
  ClientPortalViewModel? _viewModel;
  SupportConversationsViewModel? _supportViewModel;
  String? _uid;

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialTabIndex.clamp(0, 3);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = AuthScope.of(context).currentSession;
    final uid = session?.uid;
    if (uid == null || uid == _uid) return;

    _viewModel?.dispose();
    _supportViewModel?.dispose();
    _uid = uid;
    _viewModel = ClientPortalViewModel(
      repository: PortalScope.of(context),
      uid: uid,
    )..start();
    _supportViewModel = SupportConversationsViewModel(
      repository: SupportScope.of(context),
      uid: uid,
    )..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel?.dispose();
    _supportViewModel?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _viewModel?.refreshTemporalState();
    }
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
    final supportViewModel = _supportViewModel;
    if (viewModel == null || supportViewModel == null || _uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: AppTheme.background,
              child: ListenableBuilder(
                listenable: viewModel,
                builder: (context, _) {
                  final state = viewModel.state;
                  return ListenableBuilder(
                    listenable: supportViewModel,
                    builder: (context, _) => IndexedStack(
                      index: _selectedIndex,
                      children: [
                        DashboardScreen(
                          state: state,
                          viewModel: viewModel,
                          onOpenAppointments: () => _selectTab(1),
                          onOpenProfile: () => _selectTab(3),
                          onOpenBooking: () => _openBooking(viewModel),
                        ),
                        AppointmentsScreen(
                          state: state,
                          viewModel: viewModel,
                          onOpenBooking: () => _openBooking(viewModel),
                        ),
                        SupportListScreen(
                          viewModel: supportViewModel,
                          uid: _uid!,
                        ),
                        ProfileScreen(state: state),
                      ],
                    ),
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
              child: ListenableBuilder(
                listenable: supportViewModel,
                builder: (context, _) => FocusBottomNav(
                  selectedIndex: _selectedIndex,
                  unreadCount: supportViewModel.state.hasBadgeError
                      ? null
                      : supportViewModel.state.unreadCustomerCount,
                  onSelected: _selectTab,
                  onBook: () => _openBooking(viewModel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
