import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../shared/widgets/focus_count_badge.dart';
import '../../../shared/widgets/focus_empty_state.dart';
import '../../../shared/widgets/focus_glass_card.dart';
import '../../../shared/widgets/focus_status_message.dart';
import '../../../theme/app_theme.dart';
import '../application/notifications_view_model.dart';
import '../domain/notification_models.dart';
import '../domain/notification_presentation.dart';

/// Customer notification history (`users/{uid}/notifications`).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.viewModel,
    required this.onOpenTarget,
    this.now,
    super.key,
  });

  final NotificationsViewModel viewModel;
  final void Function(NotificationTarget target) onOpenTarget;
  final DateTime Function()? now;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Card whose delete action is revealed; only one at a time.
  String? _openId;

  NotificationsViewModel get _viewModel => widget.viewModel;

  Future<void> _open(AppNotification notification) async {
    final target = notification.target;
    await _viewModel.markRead(notification.id);
    if (target != null) widget.onOpenTarget(target);
  }

  Future<void> _delete(AppNotification notification) async {
    setState(() => _openId = null);
    final deleted = await _viewModel.deleteNotification(notification.id);
    if (!deleted) _showError('No hemos podido eliminar la notificación.');
  }

  Future<void> _confirmClearAll() async {
    setState(() => _openId = null);
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('¿Vaciar notificaciones?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Se eliminarán todas tus notificaciones. Esta acción no se puede deshacer.',
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              key: const Key('notifications-clear-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('notifications-clear-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: AppTheme.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Vaciar'),
            ),
          ],
        ),
      ),
    );
    if (shouldClear != true || !mounted) return;
    final cleared = await _viewModel.clearAll();
    if (!cleared) _showError('No hemos podido vaciar tus notificaciones.');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;
        final currentTime = (widget.now ?? DateTime.now)();
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
                    ? _viewModel.markAllRead
                    : null,
                icon: const Icon(Icons.done_all_rounded),
              ),
              IconButton(
                key: const Key('notifications-clear-all'),
                tooltip: 'Vaciar notificaciones',
                onPressed: state.notifications.isNotEmpty && !state.isClearing
                    ? _confirmClearAll
                    : null,
                icon: const Icon(Icons.delete_sweep_rounded),
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
        return _SwipeToDelete(
          key: ValueKey('notification-swipe-${notification.id}'),
          notificationId: notification.id,
          isOpen: _openId == notification.id,
          onOpenChanged: (open) => setState(() {
            if (open) {
              _openId = notification.id;
            } else if (_openId == notification.id) {
              _openId = null;
            }
          }),
          onDelete: () => _delete(notification),
          child: NotificationTile(
            notification: notification,
            dateLabel: formatNotificationDate(
              notification.createdAt,
              currentTime,
            ),
            onTap: () => _open(notification),
          ),
        );
      },
    );
  }
}

/// Swipe a card to the left to reveal a red "Eliminar" button behind it.
/// Swiping back, tapping the open card or opening another card cancels.
/// Screen readers get the same action as a custom semantics action.
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({
    required this.notificationId,
    required this.isOpen,
    required this.onOpenChanged,
    required this.onDelete,
    required this.child,
    super.key,
  });

  final String notificationId;
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;
  final VoidCallback onDelete;
  final Widget child;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete>
    with SingleTickerProviderStateMixin {
  static const double _actionWidth = 96;
  static const double _flingVelocity = 300;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppTheme.motion,
    value: widget.isOpen ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _SwipeToDelete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) _settle(widget.isOpen);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _settle(bool open) {
    final target = open ? 1.0 : 0.0;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = target;
    } else {
      _controller.animateTo(target, curve: Curves.easeOutCubic);
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _controller.value = (_controller.value - delta / _actionWidth).clamp(
      0.0,
      1.0,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final bool open;
    if (velocity <= -_flingVelocity) {
      open = true;
    } else if (velocity >= _flingVelocity) {
      open = false;
    } else {
      open = _controller.value >= 0.5;
    }
    _settle(open);
    if (open != widget.isOpen) widget.onOpenChanged(open);
  }

  void _close() {
    _settle(false);
    widget.onOpenChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Eliminar notificación'):
            widget.onDelete,
      },
      child: GestureDetector(
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) {
            return Stack(
              children: [
                if (_controller.value > 0)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _DeleteAction(
                        notificationId: widget.notificationId,
                        width: _actionWidth + AppTheme.radiusHero,
                        actionWidth: _actionWidth,
                        onPressed: widget.onDelete,
                      ),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(-_controller.value * _actionWidth, 0),
                  // While open, a tap on the card only closes it.
                  child: widget.isOpen
                      ? GestureDetector(
                          key: Key(
                            'notification-swipe-close-${widget.notificationId}',
                          ),
                          behavior: HitTestBehavior.opaque,
                          onTap: _close,
                          child: AbsorbPointer(child: child),
                        )
                      : child,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeleteAction extends StatelessWidget {
  const _DeleteAction({
    required this.notificationId,
    required this.width,
    required this.actionWidth,
    required this.onPressed,
  });

  final String notificationId;
  final double width;
  final double actionWidth;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Material(
        color: AppTheme.danger,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        clipBehavior: Clip.antiAlias,
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: actionWidth,
            child: Semantics(
              button: true,
              label: 'Eliminar notificación',
              excludeSemantics: true,
              child: InkWell(
                key: Key('notification-delete-$notificationId'),
                onTap: onPressed,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.white,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Eliminar',
                            maxLines: 1,
                            style: textTheme.labelMedium?.copyWith(
                              color: AppTheme.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
