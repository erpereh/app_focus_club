import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/support_repository.dart';
import '../domain/support_conversation.dart';
import '../domain/support_message.dart';

class SupportChatState {
  const SupportChatState({
    this.conversation,
    this.messages = const [],
    this.error,
    this.isLoading = true,
    this.isSending = false,
  });

  final SupportConversation? conversation;
  final List<SupportMessage> messages;
  final Object? error;
  final bool isLoading;
  final bool isSending;

  SupportChatState copyWith({
    SupportConversation? conversation,
    List<SupportMessage>? messages,
    Object? error,
    bool? isLoading,
    bool? isSending,
  }) {
    return SupportChatState(
      conversation: conversation ?? this.conversation,
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
    required SupportConversation conversation,
  }) : _repository = repository,
       _conversationId = conversation.id,
       _state = SupportChatState(conversation: conversation);

  final SupportRepository _repository;
  final String _conversationId;
  StreamSubscription<List<SupportMessage>>? _messagesSubscription;
  StreamSubscription<SupportConversation?>? _conversationSubscription;
  SupportChatState _state;
  bool _isMarkingRead = false;
  int? _lastMarkedUnreadCount;
  int? _pendingUnreadCount;
  SupportChatState get state => _state;

  void start() {
    _conversationSubscription = _repository
        .watchConversation(_conversationId)
        .listen(
          (conversation) {
            _state = _state.copyWith(conversation: conversation);
            notifyListeners();
            _markReadForConversation(conversation);
          },
          onError: (Object error) {
            _state = _state.copyWith(error: error);
            notifyListeners();
          },
        );
    _messagesSubscription = _repository
        .watchMessages(_conversationId)
        .listen(
          (messages) {
            _state = _state.copyWith(messages: messages, isLoading: false);
            notifyListeners();
          },
          onError: (Object error) {
            _state = SupportChatState(error: error, isLoading: false);
            notifyListeners();
          },
        );
    unawaited(_markRead(force: true));
  }

  Future<bool> sendMessage(String value) async {
    final text = value.trim();
    if (text.isEmpty ||
        _state.isSending ||
        _state.conversation?.isClosed == true) {
      return false;
    }

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

  void _markReadForConversation(SupportConversation? conversation) {
    final unreadCount = conversation?.unreadCustomerCount ?? 0;
    if (unreadCount == 0) {
      _lastMarkedUnreadCount = null;
      _pendingUnreadCount = null;
      return;
    }
    if (unreadCount == _lastMarkedUnreadCount ||
        unreadCount == _pendingUnreadCount) {
      return;
    }
    _pendingUnreadCount = unreadCount;
    unawaited(_markRead());
  }

  Future<void> _markRead({bool force = false}) async {
    if (_isMarkingRead) return;
    final pendingUnreadCount = _pendingUnreadCount;
    if (!force && pendingUnreadCount == null) {
      return;
    }
    _isMarkingRead = true;
    try {
      await _repository.markRead(conversationId: _conversationId);
      _lastMarkedUnreadCount = pendingUnreadCount;
      _pendingUnreadCount = null;
    } catch (_) {
      // A read receipt must not prevent the user from viewing the chat.
    } finally {
      _isMarkingRead = false;
    }
    if (_pendingUnreadCount != null &&
        _pendingUnreadCount != _lastMarkedUnreadCount) {
      unawaited(_markRead());
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _conversationSubscription?.cancel();
    super.dispose();
  }
}
