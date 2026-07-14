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

  testWidgets('closed conversation cards omit the message preview', (
    tester,
  ) async {
    const conversation = SupportConversation(
      id: 'conversation-1',
      userId: 'user-1',
      userName: 'Laura',
      userEmail: 'laura@example.com',
      status: 'closed',
      subject: 'Cuenta cerrada',
      lastMessage: 'Este preview no debe mostrarse',
      lastMessageAt: null,
      lastMessageBy: 'admin',
      unreadAdminCount: 0,
      unreadCustomerCount: 0,
      createdAt: null,
      updatedAt: null,
    );
    final repository = FakeSupportRepository(conversations: [conversation]);
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

    expect(find.text('Cuenta cerrada'), findsOneWidget);
    expect(find.text('Cerrada'), findsOneWidget);
    expect(find.text('Este preview no debe mostrarse'), findsNothing);
  });

  testWidgets(
    'closed chat hides the message composer and offers a new conversation',
    (tester) async {
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

      expect(find.text('Esta conversación está cerrada.'), findsOneWidget);
      expect(
        find.text('Abre una nueva conversación si necesitas más ayuda.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Enviar mensaje'), findsNothing);
      expect(find.text('Nueva conversación'), findsOneWidget);
    },
  );
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
