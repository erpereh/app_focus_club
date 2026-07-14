import 'package:flutter/foundation.dart';

import '../data/support_repository.dart';

class NewSupportConversationState {
  const NewSupportConversationState({this.error, this.isSubmitting = false});

  final Object? error;
  final bool isSubmitting;
}

class NewSupportConversationViewModel extends ChangeNotifier {
  NewSupportConversationViewModel({required SupportRepository repository})
    : _repository = repository;

  final SupportRepository _repository;
  NewSupportConversationState _state = const NewSupportConversationState();
  NewSupportConversationState get state => _state;

  Future<String?> create({
    required String subject,
    required String initialMessage,
  }) async {
    if (_state.isSubmitting) return null;
    _state = const NewSupportConversationState(isSubmitting: true);
    notifyListeners();
    try {
      final conversationId = await _repository.createConversation(
        subject: subject.trim(),
        initialMessage: initialMessage.trim(),
      );
      _state = const NewSupportConversationState();
      notifyListeners();
      return conversationId;
    } catch (error) {
      _state = NewSupportConversationState(error: error);
      notifyListeners();
      return null;
    }
  }
}
