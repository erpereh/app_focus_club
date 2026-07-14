import 'package:cloud_firestore/cloud_firestore.dart';

class SupportConversation {
  const SupportConversation({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.status,
    required this.subject,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageBy,
    required this.unreadAdminCount,
    required this.unreadCustomerCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String status;
  final String subject;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String lastMessageBy;
  final int unreadAdminCount;
  final int unreadCustomerCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isClosed => status.toLowerCase() == 'closed';

  factory SupportConversation.fromMap(String id, Map<String, Object?> map) {
    return SupportConversation(
      id: id,
      userId: _string(map['userId']),
      userName: _string(map['userName']),
      userEmail: _string(map['userEmail']),
      status: _string(map['status'], fallback: 'open'),
      subject: _string(map['subject']),
      lastMessage: _string(map['lastMessage']),
      lastMessageAt: parseSupportDate(map['lastMessageAt']),
      lastMessageBy: _string(map['lastMessageBy']),
      unreadAdminCount: _count(map['unreadAdminCount']),
      unreadCustomerCount: _count(map['unreadCustomerCount']),
      createdAt: parseSupportDate(map['createdAt']),
      updatedAt: parseSupportDate(map['updatedAt']),
    );
  }
}

DateTime? parseSupportDate(Object? value) {
  return switch (value) {
    null => null,
    Timestamp() => value.toDate(),
    DateTime() => value,
    String() => DateTime.tryParse(value),
    num() => DateTime.fromMillisecondsSinceEpoch(value.toInt()),
    _ => null,
  };
}

int _count(Object? value) {
  return switch (value) {
    int() => value,
    num() => value.toInt(),
    String() => int.tryParse(value) ?? 0,
    _ => 0,
  };
}

String _string(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}
