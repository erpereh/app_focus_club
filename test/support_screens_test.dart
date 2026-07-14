import 'package:app_focus_club/features/support/application/support_conversations_view_model.dart';
import 'package:app_focus_club/features/support/application/support_scope.dart';
import 'package:app_focus_club/features/support/data/support_repository.dart';
import 'package:app_focus_club/features/support/domain/support_conversation.dart';
import 'package:app_focus_club/features/support/presentation/support_chat_screen.dart';
import 'package:app_focus_club/features/support/presentation/support_list_screen.dart';
import 'package:app_focus_club/features/support/presentation/new_support_conversation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('support list shows empty state and opens the creation form', (
    tester,
  ) async {
    final repository = FakeSupportRepository();
    final viewModel = SupportConversationsViewModel(
      repository: repository,
      uid: 'user-1',
    )..start();
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      _SupportHarness(
        repository: repository,
        child: SupportListScreen(viewModel: viewModel, uid: 'user-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No tienes conversaciones todavía'), findsOneWidget);
    await tester.tap(find.text('Nueva conversación').first);
    await tester.pumpAndSettle();

    expect(find.text('Nueva conversación'), findsOneWidget);
    expect(find.text('Asunto'), findsOneWidget);
  });

  testWidgets('new conversation validates and opens the created chat', (
    tester,
  ) async {
    final repository = FakeSupportRepository();

    await tester.pumpWidget(
      _SupportHarness(
        repository: repository,
        child: const NewSupportConversationScreen(uid: 'user-1'),
      ),
    );

    await tester.tap(find.text('Abrir conversación'));
    await tester.pumpAndSettle();
    expect(
      find.text('El asunto debe tener al menos 3 caracteres.'),
      findsOneWidget,
    );
    expect(find.text('Escribe tu mensaje.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Mi bono');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Necesito resolver una duda.',
    );
    await tester.tap(find.text('Abrir conversación'));
    await tester.pumpAndSettle();

    expect(repository.createdConversations, [
      (subject: 'Mi bono', initialMessage: 'Necesito resolver una duda.'),
    ]);
    expect(find.text('Mi bono'), findsOneWidget);
  });

  testWidgets('closed chat keeps the message composer enabled', (tester) async {
    final repository = FakeSupportRepository();
    const conversation = SupportConversation(
      id: 'conversation-1',
      userId: 'user-1',
      userName: 'Laura',
      userEmail: 'laura@example.com',
      status: 'closed',
      subject: 'Cuenta',
      lastMessage: '',
      lastMessageAt: null,
      lastMessageBy: '',
      unreadAdminCount: 0,
      unreadCustomerCount: 0,
      createdAt: null,
      updatedAt: null,
    );

    await tester.pumpWidget(
      _SupportHarness(
        repository: repository,
        child: const SupportChatScreen(
          conversation: conversation,
          uid: 'user-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conversación cerrada'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '¿Podéis revisarlo?');
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pumpAndSettle();

    expect(repository.sentMessages, [
      (conversationId: 'conversation-1', text: '¿Podéis revisarlo?'),
    ]);
  });
}

class _SupportHarness extends StatelessWidget {
  const _SupportHarness({required this.repository, required this.child});

  final SupportRepository repository;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SupportScope(
      repository: repository,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }
}
