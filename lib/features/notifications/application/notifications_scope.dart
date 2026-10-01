import 'package:flutter/widgets.dart';

import '../data/notifications_repository.dart';

class NotificationsScope extends InheritedWidget {
  const NotificationsScope({
    required this.repository,
    required super.child,
    super.key,
  });

  final NotificationsRepository repository;

  static NotificationsRepository of(BuildContext context) {
    final repository = maybeOf(context);
    assert(repository != null, 'No NotificationsScope found in context.');
    return repository!;
  }

  /// Screens built without a scope (isolated widget tests) simply hide the
  /// notification history.
  static NotificationsRepository? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NotificationsScope>()
        ?.repository;
  }

  @override
  bool updateShouldNotify(NotificationsScope oldWidget) {
    return repository != oldWidget.repository;
  }
}
