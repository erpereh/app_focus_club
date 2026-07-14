import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/support_repository.dart';
import '../domain/support_conversation.dart';

class SupportConversationsState {
  const SupportConversationsState({
    this.conversations = const [],
    this.error,
    this.isLoading = true,
  });

  final List<SupportConversation> conversations;
  final Object? error;
  final bool isLoading;

  int get unreadCustomerCount => error == null
      ? conversations.fold(0, (total, item) => total + item.unreadCustomerCount)
      : 0;
  bool get hasBadgeError => error != null;

  SupportConversationsState copyWith({
    List<SupportConversation>? conversations,
    Object? error,
    bool? isLoading,
  }) {
    return SupportConversationsState(
      conversations: conversations ?? this.conversations,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SupportConversationsViewModel extends ChangeNotifier {
  SupportConversationsViewModel({
    required SupportRepository repository,
    required String uid,
  }) : _repository = repository,
       _uid = uid;

  final SupportRepository _repository;
  final String _uid;
  StreamSubscription<List<SupportConversation>>? _subscription;
  SupportConversationsState _state = const SupportConversationsState();
  SupportConversationsState get state => _state;

  void start() {
    _subscription = _repository
        .watchMyConversations(_uid)
        .listen(
          (conversations) {
            _state = SupportConversationsState(
              conversations: conversations,
              isLoading: false,
            );
            notifyListeners();
          },
          onError: (Object error) {
            _state = SupportConversationsState(error: error, isLoading: false);
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
