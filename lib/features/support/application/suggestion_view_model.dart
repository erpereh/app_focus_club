import 'package:flutter/foundation.dart';

import '../data/support_repository.dart';

class SuggestionState {
  const SuggestionState({
    this.subject = '',
    this.message = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  final String subject;
  final String message;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isSuccess;
}

class SuggestionViewModel extends ChangeNotifier {
  SuggestionViewModel({required SupportRepository repository})
    : _repository = repository;

  final SupportRepository _repository;
  SuggestionState _state = const SuggestionState();
  bool _isDisposed = false;

  SuggestionState get state => _state;

  void updateSubject(String value) {
    _state = SuggestionState(subject: value, message: _state.message);
    notifyListeners();
  }

  void updateMessage(String value) {
    _state = SuggestionState(subject: _state.subject, message: value);
    notifyListeners();
  }

  Future<bool> submit() async {
    if (_state.isSubmitting) return false;

    final subject = _state.subject.trim();
    final message = _state.message.trim();
    if (subject.length > 120 || message.length < 3 || message.length > 2000) {
      _state = SuggestionState(
        subject: _state.subject,
        message: _state.message,
        errorMessage:
            'La sugerencia no es válida. Revisa el mensaje e inténtalo de nuevo.',
      );
      notifyListeners();
      return false;
    }

    _state = SuggestionState(
      subject: _state.subject,
      message: _state.message,
      isSubmitting: true,
    );
    notifyListeners();

    try {
      await _repository.submitCustomerSuggestion(
        subject: subject.isEmpty ? null : subject,
        message: message,
      );
      if (_isDisposed) return false;
      _state = const SuggestionState(isSuccess: true);
      notifyListeners();
      return true;
    } catch (error) {
      if (_isDisposed) return false;
      _state = SuggestionState(
        subject: _state.subject,
        message: _state.message,
        errorMessage: suggestionErrorMessage(error),
      );
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
