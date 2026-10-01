import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_count_badge.dart';
import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../theme/app_theme.dart';
import '../application/notifications_view_model.dart';
import '../domain/notification_models.dart';
import '../domain/notification_presentation.dart';

/// Customer notification history (`users/{uid}/notifications`).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    required this.viewModel,
    required this.onOpenTarget,
    this.now,
    super.key,
  });

  final NotificationsViewModel viewModel;
  final void Function(NotificationTarget target) onOpenTarget;
  final DateTime Function()? now;

  Future<void> _open(AppNotification notification) async {
    final target = notification.target;
    await viewModel.markRead(notification.id);
    if (target != null) onOpenTarget(target);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final state = viewModel.state;
        final currentTime = (now ?? DateTime.now)();
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Notificaciones'),
            titleSpacing: 0,
            leading: IconButton(
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: [
              IconButton(
                key: const Key('notifications-mark-all'),
                tooltip: 'Marcar todas como leídas',
                onPressed: state.hasUnread && !state.isMarkingAll
                    ? viewModel.markAllRead
                    : null,
                icon: const Icon(Icons.done_all_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(child: _buildBody(context, state, currentTime)),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationsState state,
    DateTime currentTime,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.notifications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: FocusStatusMessage(
          message: 'No hemos podido cargar tus notificaciones.',
          type: FocusStatusType.error,
        ),
      );
    }
    if (state.notifications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: FocusEmptyState(
          title: 'Sin notificaciones',
          description:
              'Aquí verás los avisos de tus citas, bonos y mensajes del chat.',
          icon: Icons.notifications_none_rounded,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      itemCount: state.notifications.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            state.hasUnread ? '${state.unreadCount} sin leer' : 'Todas leídas',
            key: const Key('notifications-unread-summary'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          );
        }
        final notification = state.notifications[index - 1];
        return NotificationTile(
          notification: notification,
          dateLabel: formatNotificationDate(
            notification.createdAt,
            currentTime,
          ),
          onTap: () => _open(notification),
        );
      },
    );
  }
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    required this.notification,
    required this.dateLabel,
    required this.onTap,
    super.key,
  });

  final AppNotification notification;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = notificationVisualFor(
      event: notification.event,
      type: notification.type,
    );
    final textTheme = Theme.of(context).textTheme;
    final title = notification.title.isEmpty
        ? visual.label
        : notification.title;
    return Material(
      key: Key('notification-${notification.id}'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        onTap: onTap,
        child: FocusGlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    visual.icon,
                    key: Key('notification-icon-${notification.id}'),
                    color: visual.color,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: notification.read
                            ? FontWeight.w600
                            : FontWeight.w800,
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (dateLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        dateLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!notification.read)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6),
                  child: Container(
                    key: Key('notification-unread-${notification.id}'),
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppTheme.lime,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bell with unread counter shown in the Dashboard header.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    required this.unreadCount,
    required this.onPressed,
    super.key,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('dashboard-notifications-bell'),
      tooltip: unreadCount > 0
          ? 'Notificaciones, $unreadCount sin leer'
          : 'Notificaciones',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            unreadCount > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            size: 24,
          ),
          if (unreadCount > 0)
            Positioned(
              right: -8,
              top: -6,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppTheme.black,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: FocusCountBadge(
                    key: const Key('dashboard-notifications-badge'),
                    count: unreadCount,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
