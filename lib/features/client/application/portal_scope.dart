import 'package:flutter/widgets.dart';

import '../data/portal_repository.dart';

class PortalScope extends InheritedWidget {
  const PortalScope({
    required this.repository,
    required super.child,
    super.key,
  });

  final PortalRepository repository;

  static PortalRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PortalScope>();
    assert(scope != null, 'No PortalScope found in context.');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(PortalScope oldWidget) {
    return repository != oldWidget.repository;
  }
}
