import 'package:flutter/material.dart';

import '../../../shared/widgets/focus_buttons.dart';
import '../application/new_support_conversation_view_model.dart';
import '../application/support_scope.dart';
import '../data/support_repository.dart';
import '../domain/support_conversation.dart';
import 'support_chat_screen.dart';

class NewSupportConversationScreen extends StatefulWidget {
  const NewSupportConversationScreen({required this.uid, super.key});

  final String uid;

  @override
  State<NewSupportConversationScreen> createState() =>
      _NewSupportConversationScreenState();
}

class _NewSupportConversationScreenState
    extends State<NewSupportConversationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  NewSupportConversationViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel ??= NewSupportConversationViewModel(
      repository: SupportScope.of(context),
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final viewModel = _viewModel!;
    final subject = _subjectController.text.trim();
    final initialMessage = _messageController.text.trim();
    final conversationId = await viewModel.create(
      subject: subject,
      initialMessage: initialMessage,
    );
    if (!mounted) return;
    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(supportErrorMessage(viewModel.state.error!))),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SupportChatScreen(
          uid: widget.uid,
          conversation: SupportConversation(
            id: conversationId,
            userId: widget.uid,
            userName: '',
            userEmail: '',
            status: 'open',
            subject: subject,
            lastMessage: initialMessage,
            lastMessageAt: null,
            lastMessageBy: widget.uid,
            unreadAdminCount: 0,
            unreadCustomerCount: 0,
            createdAt: null,
            updatedAt: null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva conversación')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Text(
                  '¿En qué podemos ayudarte?',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Cuéntanos tu duda y el equipo de Focus Club te responderá por aquí.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _subjectController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Asunto',
                    hintText: 'Ej. Duda sobre mi bono',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'El asunto debe tener al menos 3 caracteres.'
                      : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _messageController,
                  minLines: 5,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje',
                    alignLabelWithHint: true,
                    hintText: 'Escribe los detalles de tu consulta.',
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Escribe tu mensaje.'
                      : null,
                ),
                const SizedBox(height: 28),
                FocusPrimaryButton(
                  label: 'Abrir conversación',
                  isLoading: viewModel.state.isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
