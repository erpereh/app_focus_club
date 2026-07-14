import 'package:app_focus_club/features/support/data/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
