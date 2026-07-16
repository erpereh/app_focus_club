import 'package:app_focus_club/features/support/data/support_repository.dart';
import 'package:app_focus_club/features/support/domain/customer_suggestion_request.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the shared customer suggestion callable contract', () {
    expect(supportFunctionsRegion, 'europe-west1');
    expect(customerSuggestionCallableName, 'submitCustomerSuggestion');
  });

  test('extracts a direct conversation id from callable data', () {
    expect(
      extractSupportConversationId({'conversationId': 'conversation-1'}),
      'conversation-1',
    );
  });

  test('extracts a nested conversation id from wrapped callable data', () {
    expect(
      extractSupportConversationId({
        'data': {'conversationId': 'conversation-2'},
      }),
      'conversation-2',
    );
  });

  test('rejects missing and blank conversation ids', () {
    expect(extractSupportConversationId({}), isNull);
    expect(extractSupportConversationId({'conversationId': '  '}), isNull);
  });

  test('suggestion request trims values and omits an empty subject', () {
    expect(
      const CustomerSuggestionRequest(
        subject: '   ',
        message: '  Una idea para mejorar  ',
      ).toPayload(),
      {'message': 'Una idea para mejorar'},
    );
    expect(
      const CustomerSuggestionRequest(
        subject: '  Horarios  ',
        message: '  Una idea para mejorar  ',
      ).toPayload(),
      {'subject': 'Horarios', 'message': 'Una idea para mejorar'},
    );
  });

  test('extracts suggestion id only from a successful robust map', () {
    expect(
      extractCustomerSuggestionId(<Object?, Object?>{
        'success': true,
        'suggestionId': '  suggestion-1  ',
      }),
      'suggestion-1',
    );
    expect(
      extractCustomerSuggestionId(<Object?, Object?>{
        'success': false,
        'suggestionId': 'suggestion-1',
      }),
      isNull,
    );
    expect(
      extractCustomerSuggestionId(<Object?, Object?>{
        'success': true,
        'suggestionId': '   ',
      }),
      isNull,
    );
    expect(
      extractCustomerSuggestionId(<Object?, Object?>{
        'success': true,
        'suggestionId': 42,
      }),
      isNull,
    );
  });

  test('maps suggestion callable errors to friendly messages', () {
    expect(
      suggestionErrorMessage(_FakeFunctionsException('unauthenticated')),
      'Tu sesión ha caducado. Vuelve a iniciar sesión.',
    );
    expect(
      suggestionErrorMessage(_FakeFunctionsException('invalid-argument')),
      'La sugerencia no es válida. Revisa el mensaje e inténtalo de nuevo.',
    );
    expect(
      suggestionErrorMessage(_FakeFunctionsException('resource-exhausted')),
      'Has enviado varias sugerencias seguidas. Espera un momento antes de volver a intentarlo.',
    );
    expect(
      suggestionErrorMessage(_FakeFunctionsException('unavailable')),
      'No hay conexión. Revisa la red e inténtalo de nuevo.',
    );
    expect(
      suggestionErrorMessage(StateError('unexpected')),
      'No hemos podido enviar tu sugerencia. Inténtalo de nuevo.',
    );
  });
}

class _FakeFunctionsException extends FirebaseFunctionsException {
  _FakeFunctionsException(String code) : super(code: code, message: code);
}
