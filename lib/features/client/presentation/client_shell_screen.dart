import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/application/auth_scope.dart';
import '../../notifications/application/notification_navigator.dart';
import '../../notifications/application/notifications_scope.dart';
import '../../notifications/application/notifications_view_model.dart';
import '../../notifications/domain/notification_models.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../application/client_portal_view_model.dart';
import '../application/portal_scope.dart';
import '../../../shared/widgets/focus_bottom_nav.dart';
import '../../../theme/app_theme.dart';
import '../../support/application/support_conversations_view_model.dart';
import '../../support/application/support_scope.dart';
import '../../support/domain/support_conversation.dart';
import '../../support/presentation/support_chat_screen.dart';
import '../../support/presentation/support_list_screen.dart';
import 'appointment_detail_screen.dart';
import 'appointments_screen.dart';
import 'booking_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';

class ClientShellScreen extends StatefulWidget {
  const ClientShellScreen({
    this.initialTabIndex = 0,
    this.notificationNavigator,
    super.key,
  });

  final int initialTabIndex;

  /// Defaults to [NotificationNavigator.instance].
  final NotificationNavigator? notificationNavigator;

  static const tabHome = 0;
  static const tabAppointments = 1;
  static const tabChat = 2;

  static const unavailableAppointmentMessage = 'La cita ya no está disponible.';
  static const unavailableConversationMessage =
      'No hemos podido abrir la conversación.';

  @override
  State<ClientShellScreen> createState() => _ClientShellScreenState();
}

class _ClientShellScreenState extends State<ClientShellScreen>
    with WidgetsBindingObserver {
  late int _selectedIndex;
  ClientPortalViewModel? _viewModel;
  SupportConversationsViewModel? _supportViewModel;
  NotificationsViewModel? _notificationsViewModel;
  String? _uid;

  NotificationNavigator get _navigator =>
      widget.notificationNavigator ?? NotificationNavigator.instance;

  void _selectTab(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
  }

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

    _navigator.detach(_openNotificationTarget);
    _viewModel?.dispose();
    _supportViewModel?.removeListener(_syncActiveConversation);
    _supportViewModel?.dispose();
    _notificationsViewModel?.dispose();
    _uid = uid;
    _viewModel = ClientPortalViewModel(
      repository: PortalScope.of(context),
      uid: uid,
    )..start();
    _supportViewModel = SupportConversationsViewModel(
      repository: SupportScope.of(context),
      uid: uid,
    )..start();
    _supportViewModel!.addListener(_syncActiveConversation);
    final notificationsRepository = NotificationsScope.maybeOf(context);
    _notificationsViewModel = notificationsRepository == null
        ? null
        : (NotificationsViewModel(repository: notificationsRepository, uid: uid)
            ..start());
    // Consumes a destination kept while the user was signing in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _uid == uid) _navigator.attach(_openNotificationTarget);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navigator.detach(_openNotificationTarget);
    _viewModel?.dispose();
    _supportViewModel?.removeListener(_syncActiveConversation);
    _supportViewModel?.dispose();
    _notificationsViewModel?.dispose();
    super.dispose();
  }

  void _syncActiveConversation() {
    _navigator.activeConversationId.value =
        _supportViewModel?.state.activeConversationId;
  }

  void _openNotifications(NotificationsViewModel notificationsViewModel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          viewModel: notificationsViewModel,
          onOpenTarget: _navigator.handle,
        ),
      ),
    );
  }

  /// Opens the appointment, bono or conversation a notification points to.
  Future<void> _openNotificationTarget(NotificationTarget target) async {
    if (!mounted) return;
    final viewModel = _viewModel;
    final supportViewModel = _supportViewModel;
    if (viewModel == null || supportViewModel == null) return;
    final notificationId = target.notificationId;
    if (notificationId != null) {
      unawaited(_notificationsViewModel?.markRead(notificationId));
    }
    Navigator.of(context).popUntil((route) => route.isFirst);

    switch (target.route) {
      case NotificationRoute.appointment:
        await _openAppointment(viewModel, target.appointmentId);
      case NotificationRoute.appointments:
        _selectTab(ClientShellScreen.tabAppointments);
      case NotificationRoute.bono:
        _selectTab(ClientShellScreen.tabHome);
      case NotificationRoute.chat:
        await _openConversation(supportViewModel, target.conversationId);
    }
  }

  Future<void> _openAppointment(
    ClientPortalViewModel viewModel,
    String? appointmentId,
  ) async {
    _selectTab(ClientShellScreen.tabAppointments);
    if (appointmentId == null) return;
    await _waitForAppointments(viewModel);
    if (!mounted) return;
    final appointment = viewModel.state.appointments
        .where((item) => item.id == appointmentId)
        .firstOrNull;
    if (appointment == null) {
      _showMessage(ClientShellScreen.unavailableAppointmentMessage);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailScreen(
          appointment: appointment,
          viewModel: viewModel,
        ),
      ),
    );
  }

  Future<void> _waitForAppointments(ClientPortalViewModel viewModel) async {
    if (viewModel.appointmentsLoaded) return;
    final completer = Completer<void>();
    void listener() {
      if (viewModel.appointmentsLoaded && !completer.isCompleted) {
        completer.complete();
      }
    }

    viewModel.addListener(listener);
    try {
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
    } finally {
      viewModel.removeListener(listener);
    }
  }

  Future<void> _openConversation(
    SupportConversationsViewModel supportViewModel,
    String? conversationId,
  ) async {
    _selectTab(ClientShellScreen.tabChat);
    final uid = _uid;
    if (conversationId == null || uid == null) return;
    final repository = SupportScope.of(context);
    SupportConversation? conversation;
    try {
      conversation = await repository
          .watchConversation(conversationId)
          .first
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      conversation = null;
    }
    if (!mounted) return;
    if (conversation == null) {
      _showMessage(ClientShellScreen.unavailableConversationMessage);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportChatScreen(
          conversation: conversation!,
          uid: uid,
          onConversationVisibilityChanged: (id, isVisible) {
            if (isVisible) {
              supportViewModel.setActiveConversationId(id);
            } else {
              supportViewModel.clearActiveConversationId(id);
            }
          },
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
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
                          notificationsViewModel: _notificationsViewModel,
                          onOpenNotifications: _notificationsViewModel == null
                              ? null
                              : () => _openNotifications(
                                  _notificationsViewModel!,
                                ),
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
