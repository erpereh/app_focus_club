import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../domain/notification_models.dart';
import '../domain/notification_presentation.dart';

/// A push received while the app is in the foreground.
class ForegroundNotice {
  const ForegroundNotice({
    required this.title,
    required this.body,
    required this.type,
    required this.event,
    this.target,
  });

  final String title;
  final String body;
  final String type;
  final String event;
  final NotificationTarget? target;
}

/// Decides how a foreground push is presented. The history entry already
/// exists in Firestore, so the banner never creates anything locally.
class ForegroundNotificationController extends ChangeNotifier {
  ForegroundNotificationController({
    this.displayDuration = const Duration(seconds: 5),
  });

  final Duration displayDuration;
  ForegroundNotice? _current;
  Timer? _timer;

  ForegroundNotice? get current => _current;

  /// Returns the notice to show, or `null` when it must be skipped because
  /// the customer is already looking at that support conversation.
  static ForegroundNotice? noticeFor({
    required Map<String, dynamic> data,
    required String? title,
    required String? body,
    required String? activeConversationId,
  }) {
    final target = NotificationTarget.fromPushData(data);
    final type = data['type'] is String ? data['type'] as String : '';
    final event = data['event'] is String ? data['event'] as String : type;
    if (target?.route == NotificationRoute.chat &&
        target?.conversationId != null &&
        target?.conversationId == activeConversationId) {
      return null;
    }
    final visual = notificationVisualFor(event: event, type: type);
    final resolvedTitle = (title ?? '').trim();
    final resolvedBody = (body ?? '').trim();
    if (resolvedTitle.isEmpty && resolvedBody.isEmpty && target == null) {
      return null;
    }
    return ForegroundNotice(
      title: resolvedTitle.isEmpty ? visual.label : resolvedTitle,
      body: resolvedBody,
      type: type,
      event: event,
      target: target,
    );
  }

  void show(ForegroundNotice notice) {
    _timer?.cancel();
    _current = notice;
    notifyListeners();
    _timer = Timer(displayDuration, dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Overlays the in-app banner on top of every route.
class ForegroundNotificationHost extends StatelessWidget {
  const ForegroundNotificationHost({
    required this.controller,
    required this.onOpen,
    required this.child,
    super.key,
  });

  final ForegroundNotificationController controller;
  final void Function(NotificationTarget target) onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final notice = controller.current;
            return Positioned(
              left: 12,
              right: 12,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: AnimatedSwitcher(
                  duration: AppTheme.motion,
                  child: notice == null
                      ? const SizedBox.shrink()
                      : _Banner(
                          key: ValueKey(notice),
                          notice: notice,
                          onTap: () {
                            controller.dismiss();
                            final target = notice.target;
                            if (target != null) onOpen(target);
                          },
                          onClose: controller.dismiss,
                        ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.notice,
    required this.onTap,
    required this.onClose,
    super.key,
  });

  final ForegroundNotice notice;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final visual = notificationVisualFor(
      event: notice.event,
      type: notice.type,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        key: const Key('foreground-notification-banner'),
        color: AppTheme.black,
        elevation: 8,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusHero),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppTheme.lime,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(visual.icon, color: AppTheme.onLime, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.onBlack,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (notice.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          notice.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.onBlack.withValues(alpha: 0.78),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar aviso',
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.onBlack,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
