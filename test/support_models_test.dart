import 'package:app_focus_club/features/support/domain/support_conversation.dart';
import 'package:app_focus_club/features/support/domain/support_message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'support conversation parses Firestore timestamps and nullable fields',
    () {
      final timestamp = Timestamp.fromDate(DateTime.utc(2026, 7, 14, 10, 30));

      final conversation = SupportConversation.fromMap('conversation-1', {
        'userId': 'user-1',
        'userName': 'Laura Perez',
        'userEmail': 'laura@example.com',
        'status': 'open',
        'subject': 'Duda sobre mi bono',
        'lastMessage': 'Hola',
        'lastMessageAt': timestamp,
        'lastMessageBy': 'admin-1',
        'unreadAdminCount': 2,
        'unreadCustomerCount': null,
        'createdAt': timestamp,
        'updatedAt': null,
      });

      expect(conversation.id, 'conversation-1');
      expect(
        conversation.lastMessageAt?.toUtc(),
        DateTime.utc(2026, 7, 14, 10, 30),
      );
      expect(conversation.unreadAdminCount, 2);
      expect(conversation.unreadCustomerCount, 0);
      expect(conversation.updatedAt, isNull);
    },
  );

  test('support message accepts ISO timestamps and missing timestamp', () {
    final dated = SupportMessage.fromMap('message-1', {
      'senderId': 'user-1',
      'senderRole': 'customer',
      'text': 'Necesito ayuda',
      'createdAt': '2026-07-14T10:30:00.000Z',
    });
    final pending = SupportMessage.fromMap('message-2', {
      'senderId': 'admin-1',
      'senderRole': 'admin',
      'text': 'Te ayudamos enseguida',
    });

    expect(dated.createdAt, DateTime.utc(2026, 7, 14, 10, 30));
    expect(pending.createdAt, isNull);
  });
}
