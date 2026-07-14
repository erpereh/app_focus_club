import 'package:flutter/widgets.dart';

import '../data/support_repository.dart';

class SupportScope extends InheritedWidget {
  const SupportScope({
    required this.repository,
    required super.child,
    super.key,
  });

  final SupportRepository repository;

  static SupportRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SupportScope>();
    assert(scope != null, 'No SupportScope found in context.');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(SupportScope oldWidget) {
    return repository != oldWidget.repository;
  }
}
