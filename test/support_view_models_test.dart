import 'dart:async';

import 'package:app_focus_club/features/support/application/support_chat_view_model.dart';
import 'package:app_focus_club/features/support/application/support_conversations_view_model.dart';
import 'package:app_focus_club/features/support/application/suggestion_view_model.dart';
import 'package:app_focus_club/features/support/data/support_repository.dart';
import 'package:app_focus_club/features/support/domain/support_conversation.dart';
import 'package:app_focus_club/features/support/domain/support_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'conversations view model totals unread messages and clears badge on error',
    () async {
      final repository = _SupportRepository();
      final viewModel = SupportConversationsViewModel(
        repository: repository,
        uid: 'user-1',
      )..start();

      repository.conversations.add(const [
        SupportConversation(
          id: 'one',
          userId: 'user-1',
          userName: 'Laura',
          userEmail: 'laura@example.com',
          status: 'open',
          subject: 'Bono',
          lastMessage: 'Hola',
          lastMessageAt: null,
          lastMessageBy: 'admin',
          unreadAdminCount: 0,
          unreadCustomerCount: 2,
          createdAt: null,
          updatedAt: null,
        ),
        SupportConversation(
          id: 'two',
          userId: 'user-1',
          userName: 'Laura',
          userEmail: 'laura@example.com',
          status: 'open',
          subject: 'Cuenta',
          lastMessage: 'Te ayudamos',
          lastMessageAt: null,
          lastMessageBy: 'admin',
          unreadAdminCount: 0,
          unreadCustomerCount: 3,
          createdAt: null,
          updatedAt: null,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.state.unreadCustomerCount, 5);
      expect(viewModel.state.hasBadgeError, isFalse);
      viewModel.setActiveConversationId('one');
      expect(viewModel.state.unreadCustomerCount, 3);
      viewModel.setActiveConversationId(null);

      final streamError = StateError('permission-denied');
      final streamStackTrace = StackTrace.current;
      repository.conversations.addError(streamError, streamStackTrace);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.state.unreadCustomerCount, 0);
      expect(viewModel.state.hasBadgeError, isTrue);
      expect(viewModel.state.error, same(streamError));
      expect(viewModel.state.errorStackTrace, same(streamStackTrace));
      viewModel.dispose();
    },
  );

  test(
    'chat view model marks read and sends trimmed customer messages',
    () async {
      final repository = _SupportRepository();
      final viewModel = SupportChatViewModel(
        repository: repository,
        conversation: _conversation(),
      )..start();
      await Future<void>.delayed(Duration.zero);

      await viewModel.sendMessage('  Necesito ayuda  ');

      expect(repository.markedRead, ['conversation-1']);
      expect(repository.sentMessages, [
        (conversationId: 'conversation-1', text: 'Necesito ayuda'),
      ]);
      viewModel.dispose();
    },
  );

  test(
    'chat view model coalesces read receipts while the conversation is open',
    () async {
      final repository = _SupportRepository();
      final viewModel = SupportChatViewModel(
        repository: repository,
        conversation: _conversation(unreadCustomerCount: 1),
      )..start();
      await Future<void>.delayed(Duration.zero);

      repository.conversation.add(_conversation(unreadCustomerCount: 2));
      repository.conversation.add(_conversation(unreadCustomerCount: 2));
      await Future<void>.delayed(Duration.zero);

      expect(repository.markedRead.length, lessThanOrEqualTo(2));
      viewModel.dispose();
    },
  );

  test(
    'chat view model does not send a message for a closed conversation',
    () async {
      final repository = _SupportRepository();
      final viewModel = SupportChatViewModel(
        repository: repository,
        conversation: _conversation(status: 'closed'),
      );

      expect(await viewModel.sendMessage('Necesito ayuda'), isFalse);
      expect(repository.sentMessages, isEmpty);
      viewModel.dispose();
    },
  );

  test(
    'suggestion view model trims, submits and clears only after success',
    () async {
      final repository = FakeSupportRepository();
      final viewModel = SuggestionViewModel(repository: repository)
        ..updateSubject('  Horarios  ')
        ..updateMessage('  Me gustaría ampliar los horarios  ');

      expect(await viewModel.submit(), isTrue);
      expect(repository.submittedSuggestions, [
        (subject: 'Horarios', message: 'Me gustaría ampliar los horarios'),
      ]);
      expect(viewModel.state.subject, isEmpty);
      expect(viewModel.state.message, isEmpty);
      expect(viewModel.state.isSuccess, isTrue);
      expect(viewModel.state.errorMessage, isNull);
      viewModel.dispose();
    },
  );

  test(
    'suggestion view model preserves content and unlocks after errors',
    () async {
      final repository = FakeSupportRepository(
        suggestionFailure: StateError('failed'),
      );
      final viewModel = SuggestionViewModel(repository: repository)
        ..updateSubject('Tema')
        ..updateMessage('Una sugerencia válida');

      expect(await viewModel.submit(), isFalse);
      expect(viewModel.state.subject, 'Tema');
      expect(viewModel.state.message, 'Una sugerencia válida');
      expect(viewModel.state.isSubmitting, isFalse);
      expect(viewModel.state.isSuccess, isFalse);
      expect(viewModel.state.errorMessage, isNotNull);
      viewModel.dispose();
    },
  );

  test('suggestion view model blocks duplicate pending submissions', () async {
    final repository = _SupportRepository();
    final viewModel = SuggestionViewModel(repository: repository)
      ..updateMessage('Una sugerencia válida');

    final firstSubmission = viewModel.submit();
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.state.isSubmitting, isTrue);
    expect(await viewModel.submit(), isFalse);
    expect(repository.submittedSuggestions, hasLength(1));

    repository.suggestionCompleter.complete('suggestion-1');
    expect(await firstSubmission, isTrue);
    viewModel.dispose();
  });

  test(
    'suggestion view model ignores a pending result after dispose',
    () async {
      final repository = _SupportRepository();
      final viewModel = SuggestionViewModel(repository: repository)
        ..updateMessage('Una sugerencia válida');

      final submission = viewModel.submit();
      await Future<void>.delayed(Duration.zero);
      viewModel.dispose();
      repository.suggestionCompleter.complete('suggestion-1');

      expect(await submission, isFalse);
    },
  );
}

SupportConversation _conversation({
  int unreadCustomerCount = 0,
  String status = 'open',
}) {
  return SupportConversation(
    id: 'conversation-1',
    userId: 'user-1',
    userName: 'Laura',
    userEmail: 'laura@example.com',
    status: status,
    subject: 'Cuenta',
    lastMessage: '',
    lastMessageAt: null,
    lastMessageBy: '',
    unreadAdminCount: 0,
    unreadCustomerCount: unreadCustomerCount,
    createdAt: null,
    updatedAt: null,
  );
}

class _SupportRepository implements SupportRepository {
  final conversations = StreamController<List<SupportConversation>>.broadcast();
  final messages = StreamController<List<SupportMessage>>.broadcast();
  final conversation = StreamController<SupportConversation?>.broadcast();
  final markedRead = <String>[];
  final sentMessages = <({String conversationId, String text})>[];
  final suggestionCompleter = Completer<String>();
  final submittedSuggestions = <({String? subject, String message})>[];

  @override
  Future<String> createConversation({
    required String subject,
    required String initialMessage,
  }) async => 'conversation-1';

  @override
  Future<void> markRead({required String conversationId}) async {
    markedRead.add(conversationId);
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    sentMessages.add((conversationId: conversationId, text: text));
  }

  @override
  Future<String> submitCustomerSuggestion({
    String? subject,
    required String message,
  }) {
    submittedSuggestions.add((subject: subject, message: message));
    return suggestionCompleter.future;
  }

  @override
  Stream<List<SupportConversation>> watchMyConversations(String userId) =>
      conversations.stream;

  @override
  Stream<SupportConversation?> watchConversation(String conversationId) =>
      conversation.stream;

  @override
  Stream<List<SupportMessage>> watchMessages(String conversationId) =>
      messages.stream;
}
