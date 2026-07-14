import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/support_repository.dart';
import '../domain/support_message.dart';

class SupportChatState {
  const SupportChatState({
    this.messages = const [],
    this.error,
    this.isLoading = true,
    this.isSending = false,
  });

  final List<SupportMessage> messages;
  final Object? error;
  final bool isLoading;
  final bool isSending;

  SupportChatState copyWith({
    List<SupportMessage>? messages,
    Object? error,
    bool? isLoading,
    bool? isSending,
  }) {
    return SupportChatState(
      messages: messages ?? this.messages,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
    );
  }
}

class SupportChatViewModel extends ChangeNotifier {
  SupportChatViewModel({
    required SupportRepository repository,
    required String conversationId,
  }) : _repository = repository,
       _conversationId = conversationId;

  final SupportRepository _repository;
  final String _conversationId;
  StreamSubscription<List<SupportMessage>>? _subscription;
  SupportChatState _state = const SupportChatState();
  SupportChatState get state => _state;

  void start() {
    _subscription = _repository
        .watchMessages(_conversationId)
        .listen(
          (messages) {
            _state = SupportChatState(messages: messages, isLoading: false);
            notifyListeners();
          },
          onError: (Object error) {
            _state = SupportChatState(error: error, isLoading: false);
            notifyListeners();
          },
        );
    unawaited(_markRead());
  }

  Future<bool> sendMessage(String value) async {
    final text = value.trim();
    if (text.isEmpty || _state.isSending) return false;

    _state = _state.copyWith(isSending: true);
    notifyListeners();
    try {
      await _repository.sendMessage(
        conversationId: _conversationId,
        text: text,
      );
      _state = _state.copyWith(isSending: false);
      notifyListeners();
      return true;
    } catch (error) {
      _state = _state.copyWith(error: error, isSending: false);
      notifyListeners();
      return false;
    }
  }

  Future<void> _markRead() async {
    try {
      await _repository.markRead(conversationId: _conversationId);
    } catch (_) {
      // A read receipt must not prevent the user from viewing the chat.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
