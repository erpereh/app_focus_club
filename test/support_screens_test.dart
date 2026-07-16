import 'package:app_focus_club/features/support/application/support_conversations_view_model.dart';
import 'package:app_focus_club/features/support/application/support_scope.dart';
import 'package:app_focus_club/features/support/data/support_repository.dart';
import 'package:app_focus_club/features/support/domain/support_conversation.dart';
import 'package:app_focus_club/features/support/presentation/support_chat_screen.dart';
import 'package:app_focus_club/features/support/presentation/support_list_screen.dart';
import 'package:app_focus_club/features/support/presentation/new_support_conversation_screen.dart';
import 'package:app_focus_club/theme/app_text_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('support selector preserves suggestion draft and submits it', (
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
    await tester.tap(find.text('Sugerencias'));
    await tester.pumpAndSettle();
    expect(find.text('Buzón de sugerencias'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('suggestion-subject')),
      'Horarios',
    );
    await tester.enterText(
      find.byKey(const Key('suggestion-message')),
      'Me gustaría ampliar los horarios.',
    );
    await tester.tap(find.text('Chat').first);
    await tester.pumpAndSettle();
    expect(find.text('No tienes conversaciones todavía'), findsOneWidget);
    await tester.tap(find.text('Sugerencias'));
    await tester.pumpAndSettle();

    expect(find.text('Horarios'), findsOneWidget);
    expect(find.text('Me gustaría ampliar los horarios.'), findsOneWidget);
    await tester.ensureVisible(find.text('Enviar sugerencia'));
    await tester.tap(find.text('Enviar sugerencia'));
    await tester.pumpAndSettle();

    expect(repository.submittedSuggestions, [
      (subject: 'Horarios', message: 'Me gustaría ampliar los horarios.'),
    ]);
    expect(find.text('Gracias. Hemos recibido tu sugerencia.'), findsOneWidget);
    expect(find.text('Horarios'), findsNothing);
    expect(find.text('Me gustaría ampliar los horarios.'), findsNothing);
  });

  testWidgets('suggestion form rejects empty messages and preserves errors', (
    tester,
  ) async {
    final repository = FakeSupportRepository(
      suggestionFailure: StateError('failed'),
    );
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
    await tester.tap(find.text('Sugerencias'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Enviar sugerencia'));
    await tester.tap(find.text('Enviar sugerencia'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe al menos 3 caracteres.'), findsOneWidget);
    expect(repository.submittedSuggestions, isEmpty);

    await tester.enterText(find.byKey(const Key('suggestion-subject')), 'Tema');
    await tester.enterText(
      find.byKey(const Key('suggestion-message')),
      'Una sugerencia válida',
    );
    await tester.ensureVisible(find.text('Enviar sugerencia'));
    await tester.tap(find.text('Enviar sugerencia'));
    await tester.pumpAndSettle();

    expect(
      find.text('No hemos podido enviar tu sugerencia. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Una sugerencia válida'), findsOneWidget);
    expect(find.text('Gracias. Hemos recibido tu sugerencia.'), findsNothing);
  });

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

  testWidgets('large text adapts support cards, chat and form at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const subject = 'Consulta detallada sobre mi bono mensual';
    const conversation = SupportConversation(
      id: 'conversation-1',
      userId: 'user-1',
      userName: 'Laura',
      userEmail: 'laura@example.com',
      status: 'open',
      subject: subject,
      lastMessage: 'Necesito ayuda para entender los minutos disponibles.',
      lastMessageAt: null,
      lastMessageBy: 'user-1',
      unreadAdminCount: 0,
      unreadCustomerCount: 1,
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
        largeText: true,
        child: SupportListScreen(viewModel: viewModel, uid: 'user-1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sugerencias'));
    await tester.pumpAndSettle();
    expect(find.text('Buzón de sugerencias'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Chat').first);
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text(subject)).maxLines, 2);
    await tester.tap(find.text(subject));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Enviar mensaje'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _SupportHarness(
        repository: repository,
        largeText: true,
        child: const NewSupportConversationScreen(uid: 'user-1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Asunto'), findsOneWidget);
    expect(find.text('Mensaje'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _SupportHarness extends StatelessWidget {
  const _SupportHarness({
    required this.repository,
    required this.child,
    this.largeText = false,
  });

  final SupportRepository repository;
  final Widget child;
  final bool largeText;

  @override
  Widget build(BuildContext context) {
    return SupportScope(
      repository: repository,
      child: AppTextSizeScope(
        textSize: largeText ? AppTextSize.large : AppTextSize.defaultSize,
        onChanged: (_) {},
        child: MaterialApp(
          builder: (context, appChild) => AppTextSizing.applyGlobally(
            context,
            child: appChild ?? const SizedBox.shrink(),
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
  }
}
