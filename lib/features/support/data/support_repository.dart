import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/support_conversation.dart';
import '../domain/support_message.dart';

abstract interface class SupportRepository {
  Stream<List<SupportConversation>> watchMyConversations(String userId);
  Stream<SupportConversation?> watchConversation(String conversationId);
  Stream<List<SupportMessage>> watchMessages(String conversationId);

  Future<String> createConversation({
    required String subject,
    required String initialMessage,
  });
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  });
  Future<void> markRead({required String conversationId});
}

class FirebaseSupportRepository implements SupportRepository {
  FirebaseSupportRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<List<SupportConversation>> watchMyConversations(String userId) {
    final query = _firestore
        .collection('support_conversations')
        .where('userId', isEqualTo: userId)
        .orderBy('lastMessageAt', descending: true);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => SupportConversation.fromMap(
              doc.id,
              Map<String, Object?>.from(doc.data()),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<SupportConversation?> watchConversation(String conversationId) {
    return _firestore
        .collection('support_conversations')
        .doc(conversationId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) return null;
          return SupportConversation.fromMap(
            snapshot.id,
            Map<String, Object?>.from(data),
          );
        });
  }

  @override
  Stream<List<SupportMessage>> watchMessages(String conversationId) {
    return _firestore
        .collection('support_conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SupportMessage.fromMap(
                  doc.id,
                  Map<String, Object?>.from(doc.data()),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<String> createConversation({
    required String subject,
    required String initialMessage,
  }) async {
    final result = await _functions
        .httpsCallable('createSupportConversation')
        .call<Object?>({'subject': subject, 'initialMessage': initialMessage});
    final conversationId = extractSupportConversationId(result.data);
    if (conversationId == null) {
      throw const SupportProtocolException();
    }
    return conversationId;
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    await _functions.httpsCallable('sendSupportMessage').call<Object?>({
      'conversationId': conversationId,
      'text': text,
    });
  }

  @override
  Future<void> markRead({required String conversationId}) async {
    await _functions.httpsCallable('markSupportConversationRead').call<Object?>(
      {'conversationId': conversationId},
    );
  }
}

class SupportProtocolException implements Exception {
  const SupportProtocolException();
}

String? extractSupportConversationId(Object? value) {
  if (value is! Map<Object?, Object?>) return null;
  final direct = value['conversationId'];
  if (direct is String && direct.trim().isNotEmpty) return direct.trim();
  final nested = value['data'];
  if (nested is Map<Object?, Object?>) {
    final nestedId = nested['conversationId'];
    if (nestedId is String && nestedId.trim().isNotEmpty) {
      return nestedId.trim();
    }
  }
  return null;
}

String supportErrorMessage(Object error) {
  if (error is SupportProtocolException) {
    return 'No hemos podido abrir la conversación. Inténtalo de nuevo.';
  }
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' => 'Tu sesión ha caducado. Vuelve a iniciar sesión.',
      'permission-denied' => 'No tienes permisos para realizar esta acción.',
      'failed-precondition' =>
        'Esta conversación está cerrada. Abre una nueva conversación si necesitas más ayuda.',
      'unavailable' || 'deadline-exceeded' =>
        'No hay conexión. Revisa la red e inténtalo de nuevo.',
      _ => 'No hemos podido completar la acción. Inténtalo de nuevo.',
    };
  }
  return 'No hemos podido completar la acción. Inténtalo de nuevo.';
}

class FakeSupportRepository implements SupportRepository {
  FakeSupportRepository({
    List<SupportConversation> conversations = const [],
    Map<String, List<SupportMessage>> messages = const {},
    this.createConversationId = 'conversation-1',
    this.failure,
  }) : _conversations = conversations,
       _messages = messages;

  final List<SupportConversation> _conversations;
  final Map<String, List<SupportMessage>> _messages;
  final String createConversationId;
  final Object? failure;
  final createdConversations = <({String subject, String initialMessage})>[];
  final sentMessages = <({String conversationId, String text})>[];
  final markedRead = <String>[];

  @override
  Future<String> createConversation({
    required String subject,
    required String initialMessage,
  }) async {
    if (failure != null) throw failure!;
    createdConversations.add((
      subject: subject,
      initialMessage: initialMessage,
    ));
    return createConversationId;
  }

  @override
  Future<void> markRead({required String conversationId}) async {
    if (failure != null) throw failure!;
    markedRead.add(conversationId);
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    if (failure != null) throw failure!;
    sentMessages.add((conversationId: conversationId, text: text));
  }

  @override
  Stream<List<SupportConversation>> watchMyConversations(String userId) {
    return Stream.value(
      _conversations
          .where((conversation) => conversation.userId == userId)
          .toList(),
    );
  }

  @override
  Stream<SupportConversation?> watchConversation(String conversationId) {
    final conversation = _conversations.where(
      (item) => item.id == conversationId,
    );
    return conversation.isEmpty
        ? const Stream.empty()
        : Stream.value(conversation.first);
  }

  @override
  Stream<List<SupportMessage>> watchMessages(String conversationId) {
    return Stream.value(_messages[conversationId] ?? const []);
  }
}
