import 'package:flutter/widgets.dart';

import '../data/auth_repository.dart';

class AuthScope extends InheritedWidget {
  const AuthScope({required this.repository, required super.child, super.key});

  final AuthRepository repository;

  static AuthRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope found in context.');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) {
    return repository != oldWidget.repository;
  }
}
