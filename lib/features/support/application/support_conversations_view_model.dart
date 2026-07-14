import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/support_repository.dart';
import '../domain/support_conversation.dart';

class SupportConversationsState {
  const SupportConversationsState({
    this.conversations = const [],
    this.error,
    this.errorStackTrace,
    this.activeConversationId,
    this.isLoading = true,
  });

  final List<SupportConversation> conversations;
  final Object? error;
  final StackTrace? errorStackTrace;
  final String? activeConversationId;
  final bool isLoading;

  int get unreadCustomerCount => error == null
      ? conversations
            .where((item) => item.id != activeConversationId)
            .fold(0, (total, item) => total + item.unreadCustomerCount)
      : 0;
  bool get hasBadgeError => error != null;

  SupportConversationsState copyWith({
    List<SupportConversation>? conversations,
    Object? error,
    StackTrace? errorStackTrace,
    String? activeConversationId,
    bool clearActiveConversation = false,
    bool? isLoading,
  }) {
    return SupportConversationsState(
      conversations: conversations ?? this.conversations,
      error: error,
      errorStackTrace: errorStackTrace ?? this.errorStackTrace,
      activeConversationId: clearActiveConversation
          ? null
          : activeConversationId ?? this.activeConversationId,
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
  bool _isDisposed = false;
  SupportConversationsState get state => _state;

  void start() {
    _subscription = _repository
        .watchMyConversations(_uid)
        .listen(
          (conversations) {
            _state = SupportConversationsState(
              conversations: conversations,
              activeConversationId: _state.activeConversationId,
              isLoading: false,
            );
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            _state = SupportConversationsState(
              error: error,
              errorStackTrace: stackTrace,
              activeConversationId: _state.activeConversationId,
              isLoading: false,
            );
            notifyListeners();
          },
        );
  }

  void setActiveConversationId(String? conversationId) {
    if (_isDisposed) return;
    if (_state.activeConversationId == conversationId) return;
    _state = _state.copyWith(
      activeConversationId: conversationId,
      clearActiveConversation: conversationId == null,
    );
    notifyListeners();
  }

  void clearActiveConversationId(String conversationId) {
    if (_state.activeConversationId != conversationId) return;
    setActiveConversationId(null);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
