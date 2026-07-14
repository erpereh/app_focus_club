import 'support_conversation.dart';

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderRole;
  final String text;
  final DateTime? createdAt;

  factory SupportMessage.fromMap(String id, Map<String, Object?> map) {
    return SupportMessage(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      senderRole: map['senderRole'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: parseSupportDate(map['createdAt']),
    );
  }
}
